# frozen_string_literal: true

# Stub base classes for standalone testing
module Legion
  module Extensions
    module Actors
      class Subscription
        def initialize(**_opts); end
      end
    end
  end
end
$LOADED_FEATURES << 'legion/extensions/actors/subscription'

require 'legion/extensions/audit/actors/audit_writer'

RSpec.describe Legion::Extensions::Audit::Actor::AuditWriter do
  subject(:actor) { described_class.allocate }

  it 'inherits from Legion::Extensions::Actors::Subscription' do
    expect(described_class.superclass).to eq(Legion::Extensions::Actors::Subscription)
  end

  it 'returns write as runner_function' do
    expect(actor.runner_function).to eq('write')
  end
end
