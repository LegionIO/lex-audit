# frozen_string_literal: true

require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module Audit
      module Actor
        class AuditWriter < Legion::Extensions::Actors::Subscription
          def runner_function
            'write'
          end
        end
      end
    end
  end
end
