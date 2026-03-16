# frozen_string_literal: true

module Legion
  module Extensions
    module Audit
      module Transport
        module Exchanges
          class Audit < Legion::Transport::Exchange
            def exchange_name
              'audit'
            end
          end
        end
      end
    end
  end
end
