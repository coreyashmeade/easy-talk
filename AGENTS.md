# Easy Talk

## Purpose
On-device Mac dictation proof of concept: hold a hotkey, speak, and get clean, formatted text at the cursor.

## Status
As of: 2026-10-15
- Complete and released as v0.1.0 (MIT). Archived; not maintained.
- P0 requirements built and verified (`docs/m3-results.md`); P1 requirements deferred (see `docs/prd.md`).
- Reference machine: MacBook Pro, M5 Pro, 64 GB, macOS 26.6.

## Structure / navigation
| Path | What it is |
|---|---|
| `README.md` | Overview, install, build, privacy, attributions |
| `docs/prd.md` | Requirements and delivery status |
| `docs/build-plan.md` | Milestones |
| `docs/m2-results.md`, `docs/m3-results.md` | Test results |
| `docs/design/` | Approved design source (one `.dc.html` per screen) |
| `docs/research.md` | Comparable tools and model options |
| `docs/licenses.md` | Third-party licenses and obligations |
| `decisions.md` | Decision log |
| `app/` | The app (Swift package). `app/build.sh` builds and signs `Easy Talk.app` |
| `scripts/` | Release packaging and model checksum generation |
| `tests/cleanup-cases.json` | Cleanup and safety test set |
| `spikes/` | M2 prototypes; not shipped |

## How to run / test
- Xcode 27 with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).
- Deployment target is macOS 26.0 (the Xcode 27 SDK defaults to 27).
- Build and launch: `app/build.sh --run`. Self-test: `"app/build/Easy Talk.app/Contents/MacOS/EasyTalk" --selftest tests/cleanup-cases.json`. Log: `~/Library/Logs/EasyTalk.log`. Unit tests: `xcodebuild test -scheme EasyTalk -destination 'platform=macOS,arch=arm64' -only-testing:EasyTalkCoreTests` (from `app/`).
- Development builds use a stable Apple Development identity (ad-hoc builds lose Microphone and Accessibility permission on every rebuild). Release builds are ad-hoc signed: `scripts/package-release.sh`.
- Bundle ID: `com.coreyashmeade.easytalk`.

## Conventions
- On-device only: no cloud calls, accounts, analytics or telemetry. Security rules (PRD R36 to R44) are hard requirements.
- No code copied from GPL projects (VoiceInk, FluidVoice).
- Docs, comments and commit messages use a neutral, professional voice: describe the product and decisions, not who or what did the work.
