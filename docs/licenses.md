# Easy Talk: Third-Party Licenses

Reviewed 2026-10-15 against each project's published license.

**Summary:** Easy Talk is released under the MIT License (`LICENSE`). Parakeet requires attribution to NVIDIA, provided in the README and the app's About panel. No GPL code is used.

| Component | Used for | License | Obligation |
|---|---|---|---|
| [Parakeet TDT 0.6B v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) (NVIDIA) | Speech-to-text, English | CC-BY-4.0 | Credit NVIDIA and link the license. Commercial use allowed. |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | Runs Parakeet on the Mac (Core ML) | Apache 2.0 | Keep its license notice. |
| [Parakeet v2 Core ML conversion](https://github.com/FluidInference/FluidAudio) (FluidInference on Hugging Face) | Model files FluidAudio loads | Follows Parakeet (CC-BY-4.0) | Same credit as above. |
| [Qwen 3.5 4B](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit) (Alibaba Qwen), MLX 4-bit build | Cleanup and formatting | Apache 2.0 | Keep its license notice. |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) (Apple) | Runs Qwen on the Mac | MIT | Keep its license notice. |
| Apple Speech framework | Second speech engine | Part of macOS | None. |

## Implementation notes
- **Parakeet version:** v2 (English only), matching the PRD. FluidAudio defaults to v3 (multilingual); v2 is selected explicitly.
- **Qwen 3.5 4B is a text-and-image model.** The official 2.9 GB MLX build includes unused vision weights; mlx-swift-lm loads it text-only (confirmed in M2). A smaller third-party text-only build exists but is not used.
- **Pinned downloads (PRD R40):** files come from the official Hugging Face repos at a pinned revision and are SHA-256 verified (`app/Sources/EasyTalkCore/ModelManifest.swift`). FluidAudio runs in offline mode (PRD R39).
- **Not used:** VoiceInk and FluidVoice (GPL) are research references only. No code is copied.
