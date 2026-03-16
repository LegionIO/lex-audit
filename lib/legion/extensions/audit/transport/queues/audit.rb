# frozen_string_literal: true

module Legion
  module Extensions
    module Audit
      module Transport
        module Queues
          class Audit < Legion::Transport::Queue
            def queue_name
              'audit.log'
            end

            def queue_options
              {
                arguments:   {
                  'x-single-active-consumer': true,
                  'x-dead-letter-exchange':   'audit.dlx'
                },
                auto_delete: false
              }
            end
          end
        end
      end
    end
  end
end
