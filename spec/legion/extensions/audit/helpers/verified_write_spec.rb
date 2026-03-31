# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'

# DB constant and Legion::Data::Model::AuditLog are provided by
# spec/support/audit_log_db.rb, which is loaded via spec_helper.

require 'legion/extensions/audit/helpers/verified_write'

RSpec.describe Legion::Extensions::Audit::Helpers::VerifiedWrite do
  subject(:helper) { Object.new.extend(described_class) }

  let(:tmpdir) { Dir.mktmpdir('verified_write_spec') }
  let(:path)   { File.join(tmpdir, 'test_file.txt') }
  let(:content) { "hello world\n" }

  # Access the audit_log table via the model's db connection so we work with
  # whatever database the model was bound to.
  let(:audit_db) { Legion::Data::Model::AuditLog.db }

  after { FileUtils.remove_entry(tmpdir) }

  before { audit_db[:audit_log].delete }

  # ── verified_write ─────────────────────────────────────────────────────────

  describe '#verified_write' do
    it 'writes content and returns verified result' do
      result = helper.verified_write(path, content)
      expect(result[:verified]).to be true
      expect(result[:path]).to eq(path)
      expect(result[:after_hash]).to eq(Digest::SHA256.hexdigest(content))
      expect(File.read(path)).to eq(content)
    end

    it 'sets before_hash to nil when file did not previously exist' do
      result = helper.verified_write(path, content)
      expect(result[:before_hash]).to be_nil
    end

    it 'captures before_hash of existing file' do
      File.write(path, 'old content')
      old_hash = Digest::SHA256.hexdigest('old content')
      result = helper.verified_write(path, content)
      expect(result[:before_hash]).to eq(old_hash)
    end

    it 'raises WriteVerificationError when disk content does not match' do
      allow(Digest::SHA256).to receive(:file).and_return(
        instance_double(Digest::SHA256, hexdigest: 'a' * 64)
      )

      expect do
        helper.verified_write(path, content)
      end.to raise_error(Legion::Extensions::Audit::WriteVerificationError, /write verification failed/)
    end

    it 'records an AuditLog entry when AuditLog is defined' do
      helper.verified_write(path, content, agent_id: 'agent-1')
      expect(audit_db[:audit_log].count).to eq(1)
      record = audit_db[:audit_log].first
      expect(record[:event_type]).to eq('file_operation')
      expect(record[:principal_id]).to eq('agent-1')
      expect(record[:action]).to eq('verified_write')
      expect(record[:resource]).to eq(path)
    end

    it 'uses "system" as principal_id when agent_id is nil' do
      helper.verified_write(path, content)
      expect(audit_db[:audit_log].first[:principal_id]).to eq('system')
    end

    it 'records the chain_id as source' do
      helper.verified_write(path, content, chain_id: 'my_edits')
      expect(audit_db[:audit_log].first[:source]).to eq('my_edits')
    end

    context 'when AuditLog is not defined' do
      it 'still writes and verifies without error' do
        hide_const('Legion::Data::Model::AuditLog')
        result = helper.verified_write(path, content)
        expect(result[:verified]).to be true
        expect(audit_db[:audit_log].count).to eq(0)
      end
    end
  end

  # ── verified_edit ──────────────────────────────────────────────────────────

  describe '#verified_edit' do
    let(:old_content) { "original content\n" }
    let(:new_content) { "updated content\n" }

    before { File.write(path, old_content) }

    it 'applies the edit and returns verified result' do
      result = helper.verified_edit(path, old_content, new_content)
      expect(result[:verified]).to be true
      expect(result[:after_hash]).to eq(Digest::SHA256.hexdigest(new_content))
      expect(File.read(path)).to eq(new_content)
    end

    it 'raises StaleEditError when file content has changed since read' do
      File.write(path, "somebody else changed this\n")
      expect do
        helper.verified_edit(path, old_content, new_content)
      end.to raise_error(Legion::Extensions::Audit::StaleEditError, /stale edit detected/)
    end

    it 'records an AuditLog entry for the edit' do
      helper.verified_edit(path, old_content, new_content, agent_id: 'editor-1')
      expect(audit_db[:audit_log].count).to eq(1)
      record = audit_db[:audit_log].first
      expect(record[:principal_id]).to eq('editor-1')
    end

    it 'raises WriteVerificationError when post-write verification fails' do
      real_hash = Digest::SHA256.hexdigest(old_content)
      call_count = 0
      allow(Digest::SHA256).to receive(:file) do
        call_count += 1
        # First call: staleness check — return matching hash so it passes.
        # Second call: post-write verification — return bad hash to trigger error.
        instance_double(Digest::SHA256, hexdigest: call_count == 1 ? real_hash : ('b' * 64))
      end

      expect do
        helper.verified_edit(path, old_content, new_content)
      end.to raise_error(Legion::Extensions::Audit::WriteVerificationError)
    end

    context 'when AuditLog is not defined' do
      it 'still writes and verifies without error' do
        hide_const('Legion::Data::Model::AuditLog')
        result = helper.verified_edit(path, old_content, new_content)
        expect(result[:verified]).to be true
      end
    end
  end
end
