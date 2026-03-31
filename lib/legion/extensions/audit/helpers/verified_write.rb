# frozen_string_literal: true

require 'digest'
require 'legion/extensions/audit/errors'

module Legion
  module Extensions
    module Audit
      module Helpers
        # Combines file write/edit operations with post-write SHA-256 verification
        # and optional audit trail recording via AuditRecord.
        #
        # Include this module in any class or extension that modifies files and
        # needs tamper-evident confirmation that the write succeeded.
        module VerifiedWrite
          include Legion::Extensions::Helpers::Lex if defined?(Legion::Extensions::Helpers::Lex)

          # Write +content+ to +path+, then re-read and compare SHA-256 digests.
          #
          # @param path      [String]  absolute or relative filesystem path
          # @param content   [String]  content to write
          # @param agent_id  [String, nil]  identity recorded in the audit trail
          # @param chain_id  [String]  audit chain identifier
          #
          # @return [Hash] { path:, before_hash:, after_hash:, verified: true }
          # @raise [WriteVerificationError] when re-read digest does not match written digest
          def verified_write(path, content, agent_id: nil, chain_id: 'file_edits')
            before_hash = ::File.exist?(path) ? sha256_file(path) : nil
            expected    = sha256_string(content)

            ::File.write(path, content)

            actual = sha256_file(path)
            unless actual == expected
              raise WriteVerificationError,
                    "write verification failed for #{path}: expected #{expected}, got #{actual}"
            end

            record_audit(
              path:        path,
              action:      'verified_write',
              agent_id:    agent_id,
              chain_id:    chain_id,
              before_hash: before_hash,
              after_hash:  actual
            )

            { path: path, before_hash: before_hash, after_hash: actual, verified: true }
          end

          # Apply a string-replacement edit to +path+, with a staleness check before writing
          # and SHA-256 verification after writing.
          #
          # @param path        [String]  absolute or relative filesystem path
          # @param old_content [String]  expected current file content (used for staleness check)
          # @param new_content [String]  desired file content after edit
          # @param agent_id    [String, nil]  identity recorded in the audit trail
          # @param chain_id    [String]  audit chain identifier
          #
          # @return [Hash] { path:, before_hash:, after_hash:, verified: true }
          # @raise [StaleEditError]        when the file has been modified since +old_content+ was read
          # @raise [WriteVerificationError] when re-read digest does not match written digest
          def verified_edit(path, old_content, new_content, agent_id: nil, chain_id: 'file_edits')
            before_hash   = sha256_string(old_content)
            on_disk_hash  = sha256_file(path)

            unless on_disk_hash == before_hash
              raise StaleEditError,
                    "stale edit detected for #{path}: disk content has changed since old_content was read"
            end

            verified_write(path, new_content, agent_id: agent_id, chain_id: chain_id)
          end

          private

          def sha256_string(str)
            ::Digest::SHA256.hexdigest(str)
          end

          def sha256_file(path)
            ::Digest::SHA256.file(path).hexdigest
          end

          def record_audit(path:, action:, agent_id:, chain_id:, before_hash:, after_hash:)
            return unless defined?(Legion::Data::Model::AuditLog)

            Legion::Data::Model::AuditLog.create(
              event_type:     'file_operation',
              principal_id:   agent_id || 'system',
              principal_type: 'system',
              action:         action,
              resource:       path,
              source:         chain_id,
              node:           'local',
              status:         'success',
              detail:         ::JSON.generate({ before_hash: before_hash, after_hash: after_hash }),
              record_hash:    ::Digest::SHA256.hexdigest("#{before_hash}|#{after_hash}|#{path}"),
              prev_hash:      before_hash || ('0' * 64),
              created_at:     ::Time.now.utc
            )
          rescue StandardError => e
            # audit recording is best-effort; never let it break the write
            log.warn("[lex-audit] verified_write audit record failed: #{e.message}")
            nil
          end
        end
      end
    end
  end
end
