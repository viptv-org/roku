# Roku client contract

Only the current backend contract is supported. `/api/bootstrap` must declare contract version 3. No legacy adapters, local mode, client ranking, resume thresholds or episode inference are retained.

The current presentation and remote actions are defined by [the pinned KMP adoption contract](design-contract/ROKU_KMP_REMOTE.md). See [backend requirements](docs/BACKEND_HANDOFF.md) and [qualification status](docs/REMOTE_STATUS.md). Unsupported contracts show an update-required state. Transient failures preserve current credentials and permit retry.
