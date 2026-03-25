# lex-audit: Immutable Audit Logging for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that provides immutable, tamper-evident audit logging with a SHA-256 hash chain. Records runner executions and lifecycle transitions via AMQP. Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-audit
**License**: MIT
**Version**: 0.1.2

## Architecture

```
Legion::Extensions::Audit
├── Actors/
│   └── AuditWriter        # Subscription actor: consumes audit messages, calls write runner
├── Runners/
│   └── Audit              # write: hash-chained record insert; verify: chain integrity check
└── Transport/
    ├── Exchanges/Audit    # Audit exchange
    ├── Queues/Audit       # audit.log queue (x-single-active-consumer: true)
    └── Messages/Audit     # Audit message with event_type routing key, field validation
```

## Key Files

| Path | Purpose |
|------|---------|
| `lib/legion/extensions/audit.rb` | Entry point, extension registration (`data_required? true`) |
| `lib/legion/extensions/audit/runners/audit.rb` | Hash chain write and verify logic |
| `lib/legion/extensions/audit/actors/audit_writer.rb` | AMQP subscription actor |
| `lib/legion/extensions/audit/transport/messages/audit.rb` | Message class with validation and routing |

## Runner Details

**write**: Fetches the last record's hash (or genesis hash `"0"*64`), computes SHA-256 of `prev_hash|event_type|principal_id|action|resource|created_at`, and inserts the record. Uses `.utc.iso8601` for timezone-safe hashing.

**verify**: Iterates all records in order, recomputes each hash, and compares. Returns `{ valid:, records_checked:, break_at: }`.

## Hash Chain Design

- Genesis hash: `"0" * 64` (64 zeros)
- Hash content: `"#{prev_hash}|#{event_type}|#{principal_id}|#{action}|#{resource}|#{created_at.utc.iso8601}"`
- Algorithm: SHA-256
- Single-active-consumer queue ensures ordering across cluster nodes
- `Sequel.default_timezone = :utc` required for consistent hash verification

## Integration Points

- `Legion::Audit.record` (LegionIO) publishes messages to this extension
- `Runner.run` ensure block emits `runner_execution` events
- `DigitalWorker::Lifecycle.transition!` emits `lifecycle_transition` events
- `GET /api/audit` and `GET /api/audit/verify` query the audit log
- `legion audit list` and `legion audit verify` CLI commands

## Testing

```bash
bundle install
bundle exec rspec     # 26 examples, 0 failures
bundle exec rubocop   # 0 offenses
```

---

**Maintained By**: Matthew Iverson (@Esity)
