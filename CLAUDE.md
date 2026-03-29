# lex-audit: Immutable Audit Logging for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Legion Extension that provides immutable, tamper-evident audit logging with a SHA-256 hash chain. Records runner executions and lifecycle transitions via AMQP. Also provides an approval queue for human-in-the-loop review flows. Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-audit
**License**: MIT
**Version**: 0.1.4

## Architecture

```
Legion::Extensions::Audit
├── Actor/              # Note: singular "Actor" per framework convention
│   └── AuditWriter    # Subscription actor: explicit runner_class override to
│                      # Legion::Extensions::Audit::Runners::Audit; calls write
├── Runners/
│   ├── Audit          # write: hash-chained record insert; verify: chain integrity check
│   └── ApprovalQueue  # submit, approve, reject, list_pending, show_approval
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
| `lib/legion/extensions/audit/runners/approval_queue.rb` | Human-in-the-loop approval flow |
| `lib/legion/extensions/audit/actors/audit_writer.rb` | AMQP subscription actor with explicit runner_class |
| `lib/legion/extensions/audit/transport/messages/audit.rb` | Message class with validation and routing |

## Runner Details

### Audit (`Runners::Audit`)

**write**: Fetches the last record's hash (or genesis hash `"0"*64`), computes SHA-256 of `prev_hash|event_type|principal_id|action|resource|context_snapshot|created_at`, and inserts the record. Uses `.utc.iso8601` for timezone-safe hashing. The `context_snapshot` field captures working memory state and is included in the hash chain for tamper evidence; backward-compatible with records that have no snapshot.

**verify**: Iterates all records in order, recomputes each hash, and compares. Returns `{ valid:, records_checked:, break_at: }`.

### ApprovalQueue (`Runners::ApprovalQueue`)

Human-in-the-loop review. Uses a lazy-defined Sequel model (`approval_queue` table).

| Method | Returns |
|--------|---------|
| `submit(approval_type:, payload:, requester_id:, tenant_id: nil)` | `{ success:, approval_id:, status: 'pending' }` |
| `approve(id:, reviewer_id:)` | `{ success:, approval_id:, status: 'approved' }` |
| `reject(id:, reviewer_id:)` | `{ success:, approval_id:, status: 'rejected' }` |
| `list_pending(tenant_id: nil, limit: 50)` | `{ success:, approvals: [], count: }` |
| `show_approval(id:)` | `{ success:, approval: }` |

Each state transition publishes an `Audit` message (`approval_needed` or `approval_decided`) to the audit chain.

## Hash Chain Design

- Genesis hash: `"0" * 64` (64 zeros)
- Hash content: `"#{prev_hash}|#{event_type}|#{principal_id}|#{action}|#{resource}|#{context_snapshot}|#{created_at.utc.iso8601}"`
- Algorithm: SHA-256
- Single-active-consumer queue ensures ordering across cluster nodes
- `Sequel.default_timezone = :utc` required for consistent hash verification

## Integration Points

- `Legion::Audit.record` (LegionIO) publishes messages to this extension
- `Runner.run` ensure block emits `runner_execution` events
- `DigitalWorker::Lifecycle.transition!` emits `lifecycle_transition` events
- `GET /api/audit` and `GET /api/audit/verify` query the audit log
- `legion audit list` and `legion audit verify` CLI commands

## Known Behaviour Notes

- `Actor::AuditWriter` uses `runner_class = Legion::Extensions::Audit::Runners::Audit` (class reference, not string) — this explicit override prevents the framework from attempting to resolve a non-existent `Runners::AuditWriter` constant
- Actor module is `module Actor` (singular) per framework convention

## Testing

```bash
bundle install
bundle exec rspec     # 26+ examples, 0 failures
bundle exec rubocop   # 0 offenses
```

---

**Maintained By**: Matthew Iverson (@Esity)
