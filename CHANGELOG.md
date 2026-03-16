# Changelog

## [0.1.0] - 2026-03-16

### Added
- Initial release: immutable audit logging with SHA-256 hash chain
- Transport layer: `audit` exchange, `audit.log` queue with `x-single-active-consumer`
- `Audit` message class with event_type-based routing keys and field validation
- `write` runner: creates hash-chained audit records in the database
- `verify` runner: validates hash chain integrity, detects tampering
- `AuditWriter` subscription actor: consumes audit messages from AMQP
- 29 specs, 0 failures
