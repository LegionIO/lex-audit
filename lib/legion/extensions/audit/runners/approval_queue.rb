# frozen_string_literal: true

module Legion
  module Extensions
    module Audit
      module Runners
        module ApprovalQueue
          include Legion::Extensions::Helpers::Lex if defined?(Legion::Extensions::Helpers::Lex)
          extend self

          def submit(approval_type:, payload:, requester_id:, tenant_id: nil,
                     resume_routing_key: nil, resume_exchange: nil, **)
            define_approval_queue_model
            json_payload = json_dump({ data: payload })

            create_hash = {
              approval_type: approval_type,
              payload:       json_payload,
              requester_id:  requester_id,
              status:        'pending',
              tenant_id:     tenant_id,
              created_at:    Time.now.utc
            }
            create_hash[:resume_routing_key] = resume_routing_key if resume_routing_key
            create_hash[:resume_exchange] = resume_exchange if resume_exchange

            record = Legion::Extensions::Audit::Runners::ApprovalQueue::ApprovalQueue.create(create_hash)
            publish_event('approval_needed', record)
            { success: true, approval_id: record.id, status: 'pending' }
          end

          def approve(id:, reviewer_id:, **)
            define_approval_queue_model
            record = Legion::Extensions::Audit::Runners::ApprovalQueue::ApprovalQueue[id]
            return { success: false, reason: :not_found } unless record
            return { success: false, reason: :already_decided } unless record.status == 'pending'

            record.update(status: 'approved', reviewer_id: reviewer_id, reviewed_at: Time.now.utc)
            publish_event('approval_decided', record)

            resumed = resume_pipeline(record)
            { success: true, approval_id: id, status: 'approved', resumed: resumed }
          end

          def reject(id:, reviewer_id:, **)
            define_approval_queue_model
            record = Legion::Extensions::Audit::Runners::ApprovalQueue::ApprovalQueue[id]
            return { success: false, reason: :not_found } unless record
            return { success: false, reason: :already_decided } unless record.status == 'pending'

            record.update(status: 'rejected', reviewer_id: reviewer_id, reviewed_at: Time.now.utc)
            publish_event('approval_decided', record)
            { success: true, approval_id: id, status: 'rejected' }
          end

          def list_pending(tenant_id: nil, limit: 50, **)
            define_approval_queue_model
            dataset = Legion::Extensions::Audit::Runners::ApprovalQueue::ApprovalQueue.where(status: 'pending').order(Sequel.desc(:created_at))
            dataset = dataset.where(tenant_id: tenant_id) if tenant_id
            dataset = dataset.limit(limit)
            { success: true, approvals: dataset.all.map(&:values), count: dataset.count }
          end

          def show_approval(id:, **)
            define_approval_queue_model
            record = Legion::Extensions::Audit::Runners::ApprovalQueue::ApprovalQueue[id]
            return { success: false, reason: :not_found } unless record

            { success: true, approval: record.values }
          end

          private

          def define_approval_queue_model
            return if Legion::Extensions::Audit::Runners::ApprovalQueue.const_defined?(:ApprovalQueue, false)

            db = data_connection
            return unless db&.table_exists?(:approval_queue)

            Legion::Extensions::Audit::Runners::ApprovalQueue.const_set(
              :ApprovalQueue,
              Class.new(Sequel::Model(db[:approval_queue])) do
                set_primary_key :id
              end
            )
          end

          def publish_event(event_type, record)
            return unless defined?(Legion::Extensions::Audit::Transport::Messages::Audit)

            Legion::Extensions::Audit::Transport::Messages::Audit.new(
              event_type:   event_type,
              principal_id: record.respond_to?(:requester_id) ? record.requester_id : record[:requester_id],
              action:       event_type == 'approval_needed' ? 'submit' : record.status,
              resource:     "approval_queue:#{record.id}",
              detail:       { approval_type: record.approval_type, approval_id: record.id }
            ).publish
          rescue StandardError => e
            log.warn "[audit] failed to publish #{event_type}: #{e.message}"
          end

          def resume_pipeline(record)
            return false unless record.respond_to?(:resume_routing_key) && record.resume_routing_key # rubocop:disable Legion/Extension/RunnerReturnHash

            payload = json_load(record.payload)
            routing_key = record.resume_routing_key
            function = routing_key.split('.').last

            Legion::Transport::Messages::Task.new(
              work_item:   payload[:data]&.[](:work_item) || payload[:data],
              function:    function,
              routing_key: routing_key
            ).publish
            true
          rescue StandardError => e
            log.warn("resume_pipeline failed: #{e.message}")
            false
          end
        end
      end
    end
  end
end
