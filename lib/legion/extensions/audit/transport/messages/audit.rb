# frozen_string_literal: true

module Legion
  module Extensions
    module Audit
      module Transport
        module Messages
          class Audit < Legion::Transport::Message
            def routing_key
              "audit.#{@options[:event_type] || 'unknown'}"
            end

            def type
              'audit'
            end

            def encrypt?
              false
            end

            def validate
              raise 'event_type is required' unless @options[:event_type]
              raise 'principal_id is required' unless @options[:principal_id]
              raise 'action is required' unless @options[:action]
              raise 'resource is required' unless @options[:resource]

              @valid = true
            end

            def message
              {
                event_type:     @options[:event_type],
                principal_id:   @options[:principal_id],
                principal_type: @options[:principal_type] || 'system',
                action:         @options[:action],
                resource:       @options[:resource],
                source:         @options[:source] || 'unknown',
                node:           @options[:node],
                status:         @options[:status] || 'success',
                duration_ms:    @options[:duration_ms],
                detail:         @options[:detail],
                created_at:     @options[:created_at] || Time.now.utc.iso8601
              }
            end
          end
        end
      end
    end
  end
end
