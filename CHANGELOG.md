# Changelog

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
