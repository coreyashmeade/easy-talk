# M2 Risk Check Results

2026-10-15. All three risk checks passed. Prototypes: `spikes/`. Test set: `tests/cleanup-cases.json`.

| Check | Result |
|---|---|
| Speed and quality | 34/34 cases pass. Median 0.39 s from end of speech to cleaned text; 1.7 s for a 37-second dictation. |
| Hotkey | Hold, double-tap lock and Esc cancel work. No stray spaces. Pill follows the active display across multiple screens. |
| Rich paste | HTML + RTF + plain text on the clipboard pasted correctly in the target apps tested. |

## 1. Speed and quality

**Method.** Each test phrase is synthesized with macOS text-to-speech, transcribed with Parakeet v2 (FluidAudio, Core ML), cleaned with Qwen 3.5 4B (mlx-swift-lm, 4-bit, thinking off, temperature 0), passed through the safety check (PRD R38) and scored against the case's checks.

**Speed (warm models, M5 Pro, 64 GB):**
- Transcription: about 40 ms for a short phrase; 103 ms for 37 seconds of audio.
- Cleanup: 0.23 to 0.7 s for typical dictations; 1.6 s for 37 seconds of audio.
- End of speech to cleaned text: median 0.39 s, p90 0.66 s, max 1.7 s (target: 2 s).
- Model load from disk: Parakeet 0.2 s, Qwen 0.8 s.

**Quality.** 34/34 after two changes:
- Spoken formatting commands ("new paragraph", "new line", "bullet") are applied by rules before cleanup. The model alone did not honor them. Text is split at spoken breaks, each piece is cleaned, and the pieces are rejoined.
- Two test expectations were corrected to expect digits ("3", "60,000"), per the PRD.

**Safety.** All five instruction-style dictations were returned as cleaned sentences, not acted on: a code request, "ignore your instructions", a trivia question, "summarize this" and a persona prompt. The fallback was not needed.

**Observations for the build:**
- Longer dictations are lightly reworded (within the PRD's "light reordering"); worth reviewing during daily use.
- The speech model occasionally title-cases short phrases or mishears a word.

**Decision:** keep Qwen 3.5 4B; the 8B upgrade is not needed.

## 2. Hotkey

Event-tap prototype, signed with the stable development identity:
- Hold-to-talk start and end detected for holds of 0.5 to 4.1 s.
- Key auto-repeat swallowed while held; no stray spaces in the target field.
- Taps under 0.3 s ignored; double-tap locks recording; Esc cancels.
- The pill appears on the display with the focused window, across multiple screens.
- Accessibility permission persisted across rebuilds.

## 3. Rich paste

`spikes/paste/run.sh rich` puts HTML, RTF and plain text on the clipboard together. The sample pasted correctly in the apps tested. M3 acceptance re-checks lists per app with real dictations.
