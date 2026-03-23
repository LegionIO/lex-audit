# frozen_string_literal: true

require 'digest'

module Legion
  module Extensions
    module Audit
      module Runners
        module Audit
          include Legion::Extensions::Helpers::Lex if defined?(Legion::Extensions::Helpers::Lex)

          GENESIS_HASH = ('0' * 64).freeze

          def write(event_type:, principal_id:, action:, resource:, **opts)
            prev = Legion::Data::Model::AuditLog.order(Sequel.desc(:id)).first
            prev_hash = prev ? prev.record_hash : GENESIS_HASH

            created_at = opts[:created_at] ? Time.parse(opts[:created_at].to_s) : Time.now.utc
            snapshot_json = opts[:context_snapshot] ? json_dump(opts[:context_snapshot]) : nil

            content = "#{prev_hash}|#{event_type}|#{principal_id}|#{action}|#{resource}|#{created_at.utc.iso8601}"
            content = "#{content}|#{snapshot_json}" if snapshot_json
            record_hash = Digest::SHA256.hexdigest(content)

            detail_json = opts[:detail] ? json_dump(opts[:detail]) : nil

            record = Legion::Data::Model::AuditLog.create(
              event_type:       event_type,
              principal_id:     principal_id,
              principal_type:   opts[:principal_type] || 'system',
              action:           action,
              resource:         resource,
              source:           opts[:source] || 'unknown',
              node:             opts[:node] || 'unknown',
              status:           opts[:status] || 'success',
              duration_ms:      opts[:duration_ms],
              detail:           detail_json,
              context_snapshot: snapshot_json,
              record_hash:      record_hash,
              prev_hash:        prev_hash,
              created_at:       created_at
            )

            { success: true, audit_id: record.id, record_hash: record_hash }
          end

          def verify(limit: nil, **_opts)
            prev_hash = GENESIS_HASH
            broken_at = nil
            count = 0

            dataset = Legion::Data::Model::AuditLog.order(:id)
            dataset = dataset.limit(limit) if limit

            dataset.each do |record|
              content = "#{prev_hash}|#{record.event_type}|#{record.principal_id}|#{record.action}|#{record.resource}|#{record.created_at.utc.iso8601}"
              content = "#{content}|#{record.context_snapshot}" if record.respond_to?(:context_snapshot) && record.context_snapshot
              expected = Digest::SHA256.hexdigest(content)
              unless record.record_hash == expected
                broken_at = record.id
                break
              end
              prev_hash = record.record_hash
              count += 1
            end

            { valid: broken_at.nil?, records_checked: count, break_at: broken_at }
          end
        end
      end
    end
  end
end
