# Spikes (M2 risk checks)

Prototypes used to validate the riskiest parts of Easy Talk before the app build (milestone M2). Not shipped.

| Spike | Proves | Run |
|---|---|---|
| `speed/` | Parakeet v2 + Qwen 3.5 4B are fast enough and pass `tests/cleanup-cases.json` | see `speed/run.sh` |
| `hotkey/` | Control + Option + Space can be caught in any app with no stray space | see `hotkey/run.sh` |
| `paste/` | Rich-text paste looks right in the target apps | see `paste/run.sh` |

Results are written up in `docs/m2-results.md`.
