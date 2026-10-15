# Easy Talk

A personal proof of concept for on-device dictation on macOS, built around one specific workflow. Hold **Control + Option + Space**, speak, and release: the speech is transcribed locally, cleaned up (filler words removed, lists and paragraphs formatted) and pasted at the cursor.

This is an experiment, not a product. Mature tools already cover this space, including [Wispr Flow](https://wisprflow.ai), [FluidVoice](https://github.com/altic-dev/FluidVoice), [VoiceInk](https://github.com/Beingpax/VoiceInk) and [Handy](https://github.com/cjpais/Handy). For general use, start there.

## Design constraints
- Speech recognition and text cleanup run on-device. After a one-time, checksum-verified model download, the app makes no network connections.
- The cleanup model only transforms text. It has no tools and no access to files, the screen or other apps. If its output doesn't match what was said, the raw transcript is used instead.
- Scope is deliberately narrow: English only, one hotkey, no commands, no cloud features.

Status: complete as a proof of concept (2026-10-15). The core loop is built and verified; settings, history and other P1 features are designed but not built. See `docs/m3-results.md`.

## Requirements
- Apple Silicon Mac, macOS 26 or later
- Xcode 27 with the Metal Toolchain to build

## Build
```bash
cd app
./build.sh --run
```
On first launch, setup requests Microphone and Accessibility permission, downloads the models (about 3.5 GB) and checks that they load.

Self-test (runs the pipeline on synthesized speech; no keystrokes or pastes):
```bash
"app/build/Easy Talk.app/Contents/MacOS/EasyTalk" --selftest tests/cleanup-cases.json
```

Diagnostics are written to `~/Library/Logs/EasyTalk.log` (timings and errors only, never dictated text). To reset permissions: `tccutil reset Accessibility com.coreyashmeade.easytalk` and `tccutil reset Microphone com.coreyashmeade.easytalk`.

## Documentation
| Doc | Contents |
|---|---|
| `docs/prd.md` | Requirements and acceptance criteria |
| `docs/build-plan.md` | Milestones and status |
| `docs/m2-results.md`, `docs/m3-results.md` | Test results |
| `docs/design/` | UI design |
| `docs/research.md` | Comparable tools and model options |
| `docs/licenses.md` | Third-party licenses |
| `decisions.md` | Decision log |

## Acknowledgements
- Speech recognition: [Parakeet TDT 0.6B v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) by NVIDIA (CC-BY-4.0), run with [FluidAudio](https://github.com/FluidInference/FluidAudio) (Apache 2.0)
- Text cleanup: [Qwen 3.5 4B](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit) (Apache 2.0), run with [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (MIT)
- Research references: VoiceInk, Handy, OpenWhispr and FluidVoice
