# lex-audit

Immutable audit logging with SHA-256 hash chain for [LegionIO](https://github.com/LegionIO/LegionIO). Records every runner execution and lifecycle transition as a tamper-evident audit trail.

## Installation

```bash
gem install lex-audit
```

## Functions

- **write** - Create a hash-chained audit record (each record's hash depends on the previous record)
- **verify** - Validate the entire hash chain to detect any tampering or corruption

## How It Works

Every audit record includes a SHA-256 hash computed from: `prev_hash|event_type|principal_id|action|resource|created_at`. Each record references the previous record's hash, forming an immutable chain. Breaking any record invalidates all subsequent hashes.

The `audit.log` queue uses `x-single-active-consumer: true` to ensure only one consumer writes at a time, preserving hash chain ordering across a cluster.

`Legion::Audit.record` in LegionIO publishes audit events via AMQP. It uses triple-guard checks and silent rescue to never interfere with normal operation.

## Event Types

| Type | Source | Description |
|------|--------|-------------|
| `runner_execution` | Runner.run | Every task execution with duration and status |
| `lifecycle_transition` | DigitalWorker::Lifecycle | Worker state machine transitions |

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-data` (database required)

## License

MIT
