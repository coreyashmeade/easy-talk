# Easy Talk

On-device dictation for macOS. Hold **Control + Option + Space**, speak, and release: Easy Talk transcribes the speech, removes filler words and false starts, formats lists and paragraphs, and pastes the result at the cursor.

- **Private by design.** Speech recognition and cleanup run locally. After a one-time, checksum-verified model download, the app makes no network connections.
- **Contained.** The cleanup model only transforms text. It has no tools and no access to files, the screen or other apps, and output that doesn't match what was said is replaced by the raw transcript.
- **Fast.** Typical dictations are ready in under half a second on Apple Silicon.

Status: in development (core loop). See `docs/build-plan.md`.

## Requirements
- Apple Silicon Mac, macOS 26 or later
- Xcode 27 with the Metal Toolchain to build

## Build
```bash
cd app
./build.sh --run
```
On first launch, setup requests Microphone and Accessibility permission and downloads the models (about 3.5 GB).

## Documentation
| Doc | Contents |
|---|---|
| `docs/prd.md` | Requirements and acceptance criteria |
| `docs/build-plan.md` | Milestones and status |
| `docs/design/` | Approved UI design |
| `docs/research.md` | Comparable tools and model options |
| `docs/licenses.md` | Third-party licenses |
| `decisions.md` | Decision log |

## Acknowledgements
- Speech recognition: [Parakeet TDT 0.6B v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) by NVIDIA (CC-BY-4.0), run with [FluidAudio](https://github.com/FluidInference/FluidAudio) (Apache 2.0)
- Text cleanup: [Qwen 3.5 4B](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit) (Apache 2.0), run with [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (MIT)
