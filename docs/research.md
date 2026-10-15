# Easy Talk: Research Notes

2026-10-14. Sources are each project's README and the links at the end. Feature claims are as published, not independently tested.

## 1. The core loop

1. **Trigger:** a global hotkey (hold to talk, or tap to start and tap to stop).
2. **Capture:** record from the mic while a small overlay shows it's listening.
3. **Transcribe:** a local speech-to-text model turns audio into raw text.
4. **Clean up (optional):** a language model removes filler, fixes self-corrections and formats.
5. **Insert:** paste the text where the cursor is, then restore the clipboard.

Easy Talk only needs to do this loop well. Everything else is optional.

## 2. The four reference tools

| | **FluidVoice** | **VoiceInk** | **Handy** | **OpenWhispr** |
|---|---|---|---|---|
| Platform | Mac only (macOS 15+) | Mac only (macOS 15+) | Mac, Windows, Linux | Mac, Windows, Linux, plus mobile |
| Built with | Native Swift | Native Swift | Tauri (Rust + web UI) | Electron + React |
| License | GPLv3 (cleanup model is closed) | GPLv3 (paid app, no outside contributions) | MIT | MIT |
| Speech models | Parakeet, Nemotron, Whisper, Apple Speech, Cohere | Whisper, Parakeet, SenseVoice, GGUF | Whisper, Parakeet, custom Whisper files | Whisper, Parakeet, Cohere, plus cloud |
| Cleanup / formatting | "Fluid Intelligence" local model (private, ~3.5 GB), or cloud (OpenAI, Groq) | "Smart Modes" AI enhancement | Basic optional post-processing | Local (llama.cpp) or cloud LLMs |
| Hotkey | Global hotkey | Shortcut or push-to-talk, mouse buttons | Hold-to-talk or toggle, configurable | Global hotkey |
| Insertion | Types via Accessibility API | Paste | Clipboard paste, then restores clipboard | Auto-paste at cursor |
| Live preview | Yes, words appear while speaking | Not stated | No | Not stated |
| Per-app behavior | Prompt sets per app | "Power Modes" per app or URL | No | No |
| Reads screen content | No | Yes, "context aware" | No | Optional screenshot |
| Voice commands / agent | Yes (launch apps, run shortcuts) | Voice assistant mode | No | Full AI agent, meetings, notes, teams |
| Custom dictionary | Not stated | Yes, plus text replacements | Yes (via community extension) | Not stated |
| History | Optional audio history | Not stated | Transcript history | Notes and search |
| Analytics | Anonymous analytics **on by default** | Not stated | None | Cloud sync if signed in |

### Takeaways

- **Handy (closest in spirit).** "One tool, one job." Fully local, minimal UI, hold-or-toggle hotkey, silence detection, and careful clipboard restore. A good reference for scope; minimal cleanup and formatting.
- **FluidVoice.** The most polished: live preview, notch-aware overlay, many speech models. The cleanup model is closed source, and a command mode can launch apps and run actions; Easy Talk deliberately excludes that capability.
- **VoiceInk.** Native Mac, custom dictionary, and per-app modes. Reads screen content for context, which adds privacy exposure.
- **OpenWhispr.** Broad scope: meetings, notes, teams, agents, cloud sync, enterprise SSO. Useful as a list of non-goals.

### Patterns adopted
- Hold-to-talk **and** tap-to-toggle on the same key.
- Restore the clipboard after pasting.
- Silence trimming (voice activity detection) so blank audio isn't sent to the models.
- A tiny overlay near the top of the screen or notch while recording.
- A custom word list for names and jargon (names, acronyms).
- Transcript history kept locally, so nothing is ever lost if a paste fails.

## 3. Local model options

Easy Talk needs **two** local models: one for speech-to-text, one for cleanup and formatting.

**Reference machine:** M5 Pro, 64 GB, macOS 26.6. Memory is not the constraint; latency and reliability are.

### Speech-to-text

| Option | Notes |
|---|---|
| **Parakeet TDT v2 (English)** | Very fast and accurate on Apple Silicon; used by FluidVoice, VoiceInk and Handy. Already adds punctuation and capitals. **Leading candidate.** |
| **Whisper Large v3 Turbo** | The well-known standard. Slower than Parakeet, more languages. Good fallback. |
| **Apple Speech (built into macOS 26)** | No download at all. Quality and speed need testing. |

### Cleanup and formatting

| Option | Size | Pros | Cons |
|---|---|---|---|
| **Apple Foundation Models** (built into macOS 26) | ~3B (Apple's own) | Free, no download, Apple-maintained, Swift-native, can force structured output | Requires Apple Intelligence on; small; quality on long rambles unknown |
| **Qwen 3.5 (4B to 8B instruct)** via MLX or llama.cpp | 3 to 6 GB | Strong at following formatting instructions; open license (Apache 2.0); fits easily in 64 GB | General chat model, so it can respond to dictated instructions instead of cleaning them (needs guardrails) |
| **S1-mini** (Superwhisper) | 0.6B, 462 MB | Built only for transcript cleanup; removes filler, resolves self-corrections, can make numbered lists; won't add content | Custom license (check before sharing publicly); English only; limited paragraph and bullet formatting |
| **Rules only (no LLM)** | n/a | Instant, perfectly predictable | Can remove "um", but can't restructure thoughts or format lists |

### Key findings that shape the design
- **Small general models can misbehave.** 1B-class models have been reported to write the code or answer the question that was dictated instead of cleaning it. This is the main quality and safety risk.
- **Guardrails matter more than model choice:** strict cleanup-only instructions, an output check, and a fallback to the raw transcript.
- **Keep the model warm.** macOS can page an idle model out of memory, turning a 0.2 s cleanup into several seconds.
- **Wispr Flow's own target** (from their engineering post, via the link below): about 200 ms for the cleanup step inside a 700 ms total. A good benchmark for "feels instant."

**Decision (2026-10-14):** Qwen 3.5 4B via MLX, validated with an automated test set instead of a manual model comparison. Results: `docs/m2-results.md`.

## Sources
- [FluidVoice](https://github.com/altic-dev/FluidVoice) · [VoiceInk](https://github.com/Beingpax/VoiceInk) · [Handy](https://github.com/cjpais/Handy) · [OpenWhispr](https://github.com/OpenWhispr/openwhispr)
- [S1-mini overview (Better Stack)](https://betterstack.com/community/guides/ai/s1-mini/)
- [Cleanup-pass research, small model failure modes (lexicon issue #11)](https://github.com/jparker2006/lexicon/issues/11)
- [Clean up dictated text with local AI (Moonquake Media)](https://moonquakemedia.com/blog/clean-up-dictated-text-automatically-local-ai/)
- [Apple Foundation Models framework guide (Create with Swift)](https://createwithswift.com/exploring-the-foundation-models-framework/)
- [Best MLX local LLMs on Apple Silicon 2026](https://bestllmfor.com/guides/mlx-local-llm-apple-silicon/)
