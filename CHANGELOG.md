# Changelog

## [Unreleased]

## [0.1.7] - 2026-04-13

### Added
- `ApprovalQueue#submit` accepts `resume_routing_key:` and `resume_exchange:` kwargs and stores them on the record (backward compatible — both default to nil)
- `ApprovalQueue#approve` calls `resume_pipeline` after approval: publishes a `Legion::Transport::Messages::Task` to the stored routing key so the fleet pipeline resumes processing
- `resume_pipeline` private helper: extracts work_item from stored payload, derives function name from routing key, publishes Task message

## [0.1.6] - 2026-03-31

### Added
- `Helpers::VerifiedWrite` module with `verified_write` and `verified_edit` methods
- Post-write SHA-256 verification catches silent write failures (disk full, permission, NFS stale)
- Stale edit detection catches external file modifications between read and write
- `WriteVerificationError` and `StaleEditError` error classes in `errors.rb`
- Audit trail recording via `Legion::Data::Model::AuditLog` when legion-data is available (best-effort, never breaks the write)
- Shared `spec/support/audit_log_db.rb` eliminates DB constant conflicts when all specs run together

## [0.1.5] - 2026-03-30

### Changed
- update to rubocop-legion 0.1.7, resolve all offenses

### Fixed
- Add explicit runner_class to AuditWriter actor to prevent runner resolution error at boot

## [0.1.3] - 2026-03-22

### Changed
- Add legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, legion-transport as runtime dependencies
- Replace direct Legion::JSON.dump calls with json_dump helper in runners/audit.rb and runners/approval_queue.rb
- Replace Legion::Logging.warn guarded call with log.warn helper in runners/approval_queue.rb
- Add Helpers::Lex include to runners/approval_queue.rb
- Update spec_helper with real sub-gem helper stubs (legion/transport full load)
- Update spec files to remove hand-rolled Legion::JSON stubs (real gem loaded via spec_helper)
- Update messages/audit_spec.rb validate tests to match real Transport::Message initialize behavior

## [0.1.2] - 2026-03-21

### Added
- context_snapshot field for working memory state capture in audit entries
- context_snapshot included in SHA-256 hash chain for tamper evidence
- Backward-compatible verify with mixed snapshot/non-snapshot records

## [0.1.1] - 2026-03-20

### Added
- `Runners::ApprovalQueue` with submit, approve, reject, list_pending, and show_approval methods
- Lazy Sequel model definition to avoid schema introspection at require time
- Audit event publishing via transport messages when available

## [0.1.0] - 2026-03-16

### Added
- Initial release: immutable audit logging with SHA-256 hash chain
- Transport layer: `audit` exchange, `audit.log` queue with `x-single-active-consumer`
- `Audit` message class with event_type-based routing keys and field validation
- `write` runner: creates hash-chained audit records in the database
- `verify` runner: validates hash chain integrity, detects tampering
- `AuditWriter` subscription actor: consumes audit messages from AMQP
- 29 specs, 0 failures
