# frozen_string_literal: true

require 'sequel'

Sequel.default_timezone = :utc

RESUME_SPEC_DB = Sequel.sqlite
RESUME_SPEC_DB.create_table(:approval_queue) do
  primary_key :id
  String :approval_type, null: false
  column :payload, :text
  String :requester_id, null: false
  String :status, null: false, default: 'pending'
  String :reviewer_id
  DateTime :reviewed_at
  DateTime :created_at, null: false
  String :tenant_id
  String :resume_routing_key
  String :resume_exchange
end

unless defined?(Legion::Data::Connection)
  module Legion
    module Data
      module Connection
        def self.sequel
          RESUME_SPEC_DB
        end
      end
    end
  end
end
$LOADED_FEATURES << 'legion/data' unless $LOADED_FEATURES.include?('legion/data')

# Stub transport message classes
module Legion
  module Transport
    module Messages
      class Task
        attr_reader :options

        def initialize(**opts)
          @options = opts
        end

        def publish
          # no-op in tests
        end
      end
    end
  end
end

require 'legion/extensions/audit/runners/approval_queue'

RSpec.describe 'ApprovalQueue resume functionality' do
  subject { Object.new.extend(Legion::Extensions::Audit::Runners::ApprovalQueue) }

  let(:db) { RESUME_SPEC_DB }

  before do
    @_prior_sequel = Legion::Data::Connection.method(:sequel)
    Legion::Data::Connection.define_singleton_method(:sequel) { RESUME_SPEC_DB }
    RESUME_SPEC_DB[:approval_queue].delete
    described_module = Legion::Extensions::Audit::Runners::ApprovalQueue
    described_module.send(:remove_const, :ApprovalQueue) if described_module.const_defined?(:ApprovalQueue, false)
  end

  after do
    prior = @_prior_sequel
    Legion::Data::Connection.define_singleton_method(:sequel) { prior.call }
    described_module = Legion::Extensions::Audit::Runners::ApprovalQueue
    described_module.send(:remove_const, :ApprovalQueue) if described_module.const_defined?(:ApprovalQueue, false)
  end

  let(:described_module) { Legion::Extensions::Audit::Runners::ApprovalQueue }

  describe '#submit with resume fields' do
    it 'stores resume_routing_key and resume_exchange' do
      result = subject.submit(
        approval_type: 'fleet.shipping',
        payload: { work_item: { title: 'Fix bug' } },
        requester_id: 'fleet:developer',
        resume_routing_key: 'lex.developer.runners.developer.incorporate_feedback',
        resume_exchange: 'lex.developer'
      )
      expect(result[:success]).to be true

      record = db[:approval_queue].where(id: result[:approval_id]).first
      expect(record[:resume_routing_key]).to eq('lex.developer.runners.developer.incorporate_feedback')
      expect(record[:resume_exchange]).to eq('lex.developer')
    end

    it 'works without resume fields for backward compatibility' do
      result = subject.submit(
        approval_type: 'config_change',
        payload: { key: 'val' },
        requester_id: 'user-1'
      )
      expect(result[:success]).to be true

      record = db[:approval_queue].where(id: result[:approval_id]).first
      expect(record[:resume_routing_key]).to be_nil
      expect(record[:resume_exchange]).to be_nil
    end
  end

  describe '#approve with resume' do
    let(:parsed_payload) { { data: { work_item: { title: 'Fix bug' } } } }
    let(:task_message) { instance_double(Legion::Transport::Messages::Task, publish: nil) }

    it 'publishes a Messages::Task to the stored routing key when resume fields are present' do
      submit_result = subject.submit(
        approval_type: 'fleet.escalation',
        payload: { work_item: { title: 'Fix bug', pipeline: { resumed: true } } },
        requester_id: 'fleet:developer',
        resume_routing_key: 'lex.developer.runners.developer.incorporate_feedback',
        resume_exchange: 'lex.developer'
      )

      allow(subject).to receive(:json_load).and_return(parsed_payload)
      allow(Legion::Transport::Messages::Task).to receive(:new).and_return(task_message)

      result = subject.approve(id: submit_result[:approval_id], reviewer_id: 'human-1')
      expect(result[:success]).to be true
      expect(result[:status]).to eq('approved')
      expect(result[:resumed]).to be true
      expect(Legion::Transport::Messages::Task).to have_received(:new).with(
        hash_including(routing_key: 'lex.developer.runners.developer.incorporate_feedback')
      )
      expect(task_message).to have_received(:publish)
    end

    it 'stores payload with resumed: true before persisting' do
      submit_result = subject.submit(
        approval_type: 'fleet.escalation',
        payload: { work_item: { title: 'Fix bug', pipeline: { resumed: true } } },
        requester_id: 'fleet:developer',
        resume_routing_key: 'lex.developer.runners.developer.incorporate_feedback',
        resume_exchange: 'lex.developer'
      )

      record = db[:approval_queue].where(id: submit_result[:approval_id]).first
      stored = JSON.parse(record[:payload], symbolize_names: true)
      expect(stored.dig(:data, :work_item, :pipeline, :resumed)).to be true
    end

    it 'does not publish when no resume fields are present' do
      submit_result = subject.submit(
        approval_type: 'config_change',
        payload: { key: 'val' },
        requester_id: 'user-1'
      )

      result = subject.approve(id: submit_result[:approval_id], reviewer_id: 'human-1')
      expect(result[:success]).to be true
      expect(result[:resumed]).to be_falsey
    end
  end

  describe '#show_approval with resume fields' do
    it 'includes resume fields in the approval record' do
      submit_result = subject.submit(
        approval_type: 'fleet.escalation',
        payload: { work_item: { title: 'Fix bug', pipeline: { resumed: true } } },
        requester_id: 'fleet:developer',
        resume_routing_key: 'lex.developer.runners.developer.incorporate_feedback',
        resume_exchange: 'lex.developer'
      )

      result = subject.show_approval(id: submit_result[:approval_id])
      expect(result[:success]).to be true
      expect(result[:approval][:resume_routing_key]).to eq('lex.developer.runners.developer.incorporate_feedback')
      expect(result[:approval][:resume_exchange]).to eq('lex.developer')
    end
  end
end
