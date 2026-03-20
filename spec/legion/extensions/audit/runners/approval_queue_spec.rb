# frozen_string_literal: true

require 'sequel'
require 'json'

# In-memory SQLite database for testing
Sequel.default_timezone = :utc
APPROVAL_QUEUE_DB = Sequel.sqlite
APPROVAL_QUEUE_DB.create_table(:approval_queue) do
  primary_key :id
  String :approval_type, null: false
  column :payload, :text
  String :requester_id, null: false
  String :status, null: false, default: 'pending'
  String :reviewer_id
  DateTime :reviewed_at
  DateTime :created_at, null: false
  String :tenant_id
end

module Legion
  module Data
    module Connection
      def self.sequel
        APPROVAL_QUEUE_DB
      end
    end
  end

  module JSON
    def self.dump(obj)
      ::JSON.generate(obj)
    end

    def self.load(str)
      ::JSON.parse(str, symbolize_names: true)
    end
  end
end
$LOADED_FEATURES << 'legion/data'
$LOADED_FEATURES << 'legion/json'

require 'legion/extensions/audit/runners/approval_queue'

RSpec.describe Legion::Extensions::Audit::Runners::ApprovalQueue do
  subject { Object.new.extend(described_class) }

  before do
    APPROVAL_QUEUE_DB[:approval_queue].delete
    described_class.send(:remove_const, :ApprovalQueue) if described_class.const_defined?(:ApprovalQueue, false)
  end

  describe '#submit' do
    it 'creates a pending approval record' do
      result = subject.submit(approval_type: 'worker_deploy', payload: { name: 'test' },
                              requester_id: 'user-1')
      expect(result[:success]).to be true
      expect(result[:status]).to eq('pending')
      expect(result[:approval_id]).to be_a(Integer)
    end

    it 'stores the payload as JSON' do
      subject.submit(approval_type: 'config_change', payload: { key: 'val' },
                     requester_id: 'user-1')
      record = APPROVAL_QUEUE_DB[:approval_queue].first
      expect(record[:payload]).to include('key')
    end
  end

  describe '#approve' do
    it 'approves a pending record' do
      submit_result = subject.submit(approval_type: 'test', payload: {}, requester_id: 'user-1')
      result = subject.approve(id: submit_result[:approval_id], reviewer_id: 'reviewer-1')
      expect(result[:success]).to be true
      expect(result[:status]).to eq('approved')
    end

    it 'rejects approving a non-pending record' do
      submit_result = subject.submit(approval_type: 'test', payload: {}, requester_id: 'user-1')
      subject.approve(id: submit_result[:approval_id], reviewer_id: 'reviewer-1')
      result = subject.approve(id: submit_result[:approval_id], reviewer_id: 'reviewer-2')
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:already_decided)
    end

    it 'returns not_found for missing id' do
      result = subject.approve(id: 9999, reviewer_id: 'reviewer-1')
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end
  end

  describe '#reject' do
    it 'rejects a pending record' do
      submit_result = subject.submit(approval_type: 'test', payload: {}, requester_id: 'user-1')
      result = subject.reject(id: submit_result[:approval_id], reviewer_id: 'reviewer-1')
      expect(result[:success]).to be true
      expect(result[:status]).to eq('rejected')
    end
  end

  describe '#list_pending' do
    it 'returns only pending approvals' do
      subject.submit(approval_type: 'a', payload: {}, requester_id: 'u1')
      submit2 = subject.submit(approval_type: 'b', payload: {}, requester_id: 'u2')
      subject.approve(id: submit2[:approval_id], reviewer_id: 'r1')

      result = subject.list_pending
      expect(result[:success]).to be true
      expect(result[:approvals].size).to eq(1)
      expect(result[:approvals].first[:approval_type]).to eq('a')
    end

    it 'filters by tenant_id' do
      subject.submit(approval_type: 'a', payload: {}, requester_id: 'u1', tenant_id: 'tenant-1')
      subject.submit(approval_type: 'b', payload: {}, requester_id: 'u2', tenant_id: 'tenant-2')

      result = subject.list_pending(tenant_id: 'tenant-1')
      expect(result[:approvals].size).to eq(1)
    end
  end
end
