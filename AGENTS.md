# Easy Talk

## Purpose
Private, on-device Mac dictation: hold a hotkey, speak, and get clean, formatted text at the cursor. Built to be safe to share publicly.

## Status
As of: 2026-10-15
- M0 to M2 complete; **M3 (core loop, P0) in progress**. See `docs/build-plan.md`.
- PRD approved 2026-10-14; design approved 2026-10-15.
- Reference machine: MacBook Pro, M5 Pro, 64 GB, macOS 26.6.
- Repo: [github.com/coreyashmeade/easy-talk](https://github.com/coreyashmeade/easy-talk) (private).

## Structure / navigation
| Path | What it is |
|---|---|
| `README.md` | Overview, build steps, attributions |
| `docs/prd.md` | Requirements; source of truth for v1 behavior |
| `docs/build-plan.md` | Milestones and status |
| `docs/design/` | Approved design source (one `.dc.html` per screen) |
| `docs/research.md` | Comparable tools and model options |
| `docs/licenses.md` | Third-party licenses and obligations |
| `docs/m2-results.md` | Risk-check results |
| `decisions.md` | Decision log |
| `app/` | The app (Swift package). `app/build.sh` builds and signs `Easy Talk.app` |
| `tests/cleanup-cases.json` | Cleanup and safety test set |
| `spikes/` | M2 prototypes; not shipped |
| `scripts/make-model-manifest.py` | Regenerates pinned model checksums |

External: [design canvas](https://claude.ai/artifact/WAMdyNsJ8XFLAp7ThQKXgm) (design source of truth) · [PRD review copy](https://docs.google.com/document/d/1pZq8I37jNmak-zqDJ4V23wLglsErYRsfaxu_2fevpiY/edit) (Google Doc; update `docs/prd.md` first, then sync the Doc in place) · [Figma](https://www.figma.com/design/H1IsUOgIJ2eEiqjm1yb7Nr) (paused, out of date).

## How to run / test
- Xcode 27 with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).
- Deployment target is macOS 26.0 (the Xcode 27 SDK defaults to 27).
- Build and launch: `app/build.sh --run`. Unit tests: `xcodebuild test -scheme EasyTalk -destination 'platform=macOS,arch=arm64' -only-testing:EasyTalkCoreTests` (from `app/`).
- Sign with a stable Apple Development identity, never ad-hoc; ad-hoc builds lose Microphone and Accessibility permission on every rebuild. Signing needs Apple's WWDR G3 intermediate in the login keychain.
- Bundle ID: `com.coreyashmeade.easytalk`.

## Conventions
- Requirements docs follow the `prd-style` skill.
- On-device only: no cloud calls, accounts, analytics or telemetry. Security rules (PRD R36 to R44) are hard requirements.
- No code copied from GPL projects (VoiceInk, FluidVoice).
- Write repo docs, comments and commit messages in a neutral, professional voice: describe the product and decisions, not who or what did the work.
