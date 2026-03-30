# frozen_string_literal: true

require 'digest'
require 'sequel'
require 'json'

# In-memory SQLite database for testing
Sequel.default_timezone = :utc
DB = Sequel.sqlite
DB.create_table(:audit_log) do
  primary_key :id
  String   :event_type,     null: false, size: 50
  String   :principal_id,   null: false, size: 255
  String   :principal_type, null: false, size: 20
  String   :action,         null: false, size: 100
  String   :resource,       null: false, size: 500
  String   :source,         null: false, size: 20
  String   :node,           null: false, size: 255
  String   :status,         null: false, size: 20
  Integer  :duration_ms,    null: true
  column   :detail,         :text, null: true
  column   :context_snapshot, :text, null: true
  String   :record_hash,    null: false, size: 64
  String   :prev_hash,      null: false, size: 64
  DateTime :created_at,     null: false
end

# Stub the model
module Legion
  module Data
    module Model
      class AuditLog < Sequel::Model(DB[:audit_log]); end # rubocop:disable Legion/Framework/EagerSequelModel
    end
  end
end
$LOADED_FEATURES << 'legion/data/models/audit_log'

require 'legion/extensions/audit/runners/audit'

RSpec.describe Legion::Extensions::Audit::Runners::Audit do
  let(:runner) { Object.new.extend(described_class) }
  let(:genesis_hash) { '0' * 64 }

  before(:each) do
    DB[:audit_log].delete
  end

  describe '#write' do
    it 'creates an audit record with all fields' do
      result = runner.write(
        event_type: 'runner_execution', principal_id: 'worker-1',
        action: 'execute', resource: 'MyRunner/run', source: 'amqp',
        node: 'node-01', status: 'success', duration_ms: 42,
        detail: { task_id: 1 }
      )
      expect(result[:success]).to be true
      expect(result[:audit_id]).not_to be_nil
      expect(result[:record_hash]).to be_a(String)
      expect(result[:record_hash].length).to eq(64)
    end

    it 'uses genesis hash as prev_hash for first record' do
      runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      record = Legion::Data::Model::AuditLog.first
      expect(record.prev_hash).to eq(genesis_hash)
    end

    it 'chains second record to first' do
      first = runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      runner.write(
        event_type: 'runner_execution', principal_id: 'w2',
        action: 'execute', resource: 'R/g'
      )
      second = Legion::Data::Model::AuditLog.order(:id).last
      expect(second.prev_hash).to eq(first[:record_hash])
    end

    it 'produces deterministic hashes' do
      frozen_time = Time.utc(2026, 3, 16, 12, 0, 0)
      allow(Time).to receive(:now).and_return(frozen_time)

      r1 = runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      DB[:audit_log].delete

      r2 = runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      expect(r1[:record_hash]).to eq(r2[:record_hash])
    end

    it 'changes hash when any field changes (tamper detection)' do
      frozen_time = Time.utc(2026, 3, 16, 12, 0, 0)
      allow(Time).to receive(:now).and_return(frozen_time)

      r1 = runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      DB[:audit_log].delete

      r2 = runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/g'
      )
      expect(r1[:record_hash]).not_to eq(r2[:record_hash])
    end

    it 'stores detail as JSON string' do
      runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f',
        detail: { task_id: 99, error: nil }
      )
      record = Legion::Data::Model::AuditLog.first
      expect(record.detail).to be_a(String)
      parsed = JSON.parse(record.detail, symbolize_names: true)
      expect(parsed[:task_id]).to eq(99)
    end

    it 'defaults principal_type to system' do
      runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      expect(Legion::Data::Model::AuditLog.first.principal_type).to eq('system')
    end

    it 'defaults source to unknown' do
      runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      expect(Legion::Data::Model::AuditLog.first.source).to eq('unknown')
    end

    it 'stores context_snapshot when provided' do
      result = runner.write(
        event_type:       'action_executed',
        principal_id:     'agent-1',
        action:           'approve_claim',
        resource:         'claim:12345',
        context_snapshot: {
          working_memory: [{ trace_id: 't1', content: 'policy lookup', activation: 0.9 }],
          trust_scores:   { 'agent-2' => 0.85 }
        }
      )
      expect(result[:success]).to be true
      record = Legion::Data::Model::AuditLog.last
      expect(record.context_snapshot).to be_a(String)
      parsed = JSON.parse(record.context_snapshot, symbolize_names: true)
      expect(parsed[:working_memory]).to be_an(Array)
    end

    it 'writes successfully without context_snapshot (backward compatible)' do
      result = runner.write(
        event_type:   'simple_event',
        principal_id: 'system',
        action:       'heartbeat',
        resource:     'node:1'
      )
      expect(result[:success]).to be true
      record = Legion::Data::Model::AuditLog.last
      expect(record.context_snapshot).to be_nil
    end

    it 'includes context_snapshot in hash chain' do
      frozen_time = Time.utc(2026, 3, 21, 12, 0, 0)
      allow(Time).to receive(:now).and_return(frozen_time)

      r1 = runner.write(
        event_type: 'test', principal_id: 'w1',
        action: 'execute', resource: 'R/f'
      )
      DB[:audit_log].delete

      r2 = runner.write(
        event_type: 'test', principal_id: 'w1',
        action: 'execute', resource: 'R/f',
        context_snapshot: { data: 'something' }
      )
      # Hash should differ when snapshot is present
      expect(r1[:record_hash]).not_to eq(r2[:record_hash])
    end
  end

  describe '#verify' do
    it 'returns valid for empty chain' do
      result = runner.verify
      expect(result[:valid]).to be true
      expect(result[:records_checked]).to eq(0)
      expect(result[:break_at]).to be_nil
    end

    it 'returns valid for intact chain' do
      3.times { |i| runner.write(event_type: 'runner_execution', principal_id: "w#{i}", action: 'execute', resource: 'R/f') }
      result = runner.verify
      expect(result[:valid]).to be true
      expect(result[:records_checked]).to eq(3)
    end

    it 'detects tampered record' do
      3.times { |i| runner.write(event_type: 'runner_execution', principal_id: "w#{i}", action: 'execute', resource: 'R/f') }
      tampered = Legion::Data::Model::AuditLog.order(:id).all[1]
      DB[:audit_log].where(id: tampered.id).update(record_hash: 'x' * 64)
      result = runner.verify
      expect(result[:valid]).to be false
      expect(result[:break_at]).to eq(tampered.id)
    end

    it 'respects limit parameter' do
      5.times { |i| runner.write(event_type: 'runner_execution', principal_id: "w#{i}", action: 'execute', resource: 'R/f') }
      result = runner.verify(limit: 3)
      expect(result[:records_checked]).to eq(3)
      expect(result[:valid]).to be true
    end

    it 'verifies chain with context_snapshot records' do
      runner.write(
        event_type: 'runner_execution', principal_id: 'w1',
        action: 'execute', resource: 'R/f',
        context_snapshot: { traces: ['t1'] }
      )
      runner.write(
        event_type: 'runner_execution', principal_id: 'w2',
        action: 'execute', resource: 'R/g'
      )
      result = runner.verify
      expect(result[:valid]).to be true
      expect(result[:records_checked]).to eq(2)
    end
  end
end
