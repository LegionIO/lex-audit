# frozen_string_literal: true

# Stub Legion::Transport::Message for standalone testing
module Legion
  module Transport
    class Message
      def initialize(**opts)
        @options = opts
      end
    end
  end
end
$LOADED_FEATURES << 'legion/transport/message'

require 'legion/extensions/audit/transport/messages/audit'

RSpec.describe Legion::Extensions::Audit::Transport::Messages::Audit do
  subject(:msg) { described_class.new(**valid_opts) }

  let(:valid_opts) do
    {
      event_type:   'runner_execution',
      principal_id: 'worker-123',
      action:       'execute',
      resource:     'MyRunner/my_function',
      source:       'amqp',
      node:         'node-01',
      status:       'success',
      duration_ms:  42
    }
  end

  describe '#routing_key' do
    it 'includes event_type' do
      expect(msg.routing_key).to eq('audit.runner_execution')
    end

    it 'defaults to unknown when event_type is nil' do
      msg = described_class.new(**valid_opts, event_type: nil)
      expect(msg.routing_key).to eq('audit.unknown')
    end
  end

  describe '#type' do
    it 'returns audit' do
      expect(msg.type).to eq('audit')
    end
  end

  describe '#encrypt?' do
    it 'returns false' do
      expect(msg.encrypt?).to be false
    end
  end

  describe '#validate' do
    it 'succeeds with valid options' do
      expect { msg.validate }.not_to raise_error
    end

    %i[event_type principal_id action resource].each do |field|
      it "raises when #{field} is missing" do
        opts = valid_opts.dup
        opts.delete(field)
        bad_msg = described_class.new(**opts)
        expect { bad_msg.validate }.to raise_error(RuntimeError, /#{field}.*required/)
      end
    end
  end

  describe '#message' do
    it 'includes all fields in the payload' do
      payload = msg.message
      expect(payload[:event_type]).to eq('runner_execution')
      expect(payload[:principal_id]).to eq('worker-123')
      expect(payload[:action]).to eq('execute')
      expect(payload[:resource]).to eq('MyRunner/my_function')
      expect(payload[:source]).to eq('amqp')
      expect(payload[:node]).to eq('node-01')
      expect(payload[:status]).to eq('success')
      expect(payload[:duration_ms]).to eq(42)
      expect(payload[:created_at]).not_to be_nil
    end

    it 'defaults principal_type to system' do
      expect(msg.message[:principal_type]).to eq('system')
    end

    it 'defaults source to unknown when not provided' do
      msg = described_class.new(**valid_opts.tap { |o| o.delete(:source) })
      expect(msg.message[:source]).to eq('unknown')
    end
  end
end
