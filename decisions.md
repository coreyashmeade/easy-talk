# Decisions

Newest at the bottom. Format: `YYYY-MM-DD: <decision>. Why: <reason>. Replaces: <earlier decision, if any>.`

2026-10-14: Scope is a small core-mechanics dictation tool, informed by VoiceInk, Handy, OpenWhispr and FluidVoice. Why: cover the core loop well without rebuilding a full product.
2026-10-14: All processing on-device; the language model is text-in, text-out only (no tools, files, network or commands). Why: privacy, and safe to share publicly later.
2026-10-14: Paste as rich text with a plain-text fallback; English only; Parakeet and Apple speech, chosen during setup. Why: real lists in target apps; English is the only requirement.
2026-10-14: Trigger is hold Control + Option + Space. Why: Option + Space conflicts with the ChatGPT desktop launcher; Control + Option + Space is free on the reference machine. Replaces: Left Option + Space.
2026-10-14: Cleanup model is Qwen 3.5 4B (MLX), validated with an automated test set rather than a manual model comparison. Why: open license, strong instruction following, fast on Apple Silicon.
2026-10-14: PRD approved (`docs/prd.md`).
2026-10-15: Pill sits at the lower middle of the active display, just above the Dock, 86% opaque with background blur. Why: multi-monitor use; chat inputs are usually near the bottom of the screen in use. Replaces: pill below the notch.
2026-10-15: Visual identity: warm yellow and red palette, cream windows, a cat-ear pill silhouette, a three-line zig-zag mark, and subtle dark outlines on icons. Replaces: graphite pill with teal accents.
2026-10-15: Design approved; source snapshot in `docs/design/`. The Figma copy is paused and out of date.
2026-10-15: Build plan adopted with risk checks (hotkey, speed/quality, rich paste) before the core loop. Why: retire the riskiest unknowns before building around them.
2026-10-15: Parakeet v2 (English) selected explicitly. Why: matches the English-only scope; the library default is multilingual v3.
2026-10-15: Builds target macOS 26.0 and are signed with a stable Apple Development identity. Why: the Xcode 27 SDK targets macOS 27 by default; stable signing keeps Microphone and Accessibility permissions across rebuilds.
2026-10-15: Spoken formatting commands ("new paragraph", "new line", "bullet") are applied by rules before cleanup; text is split at spoken breaks and each piece cleaned separately. Why: the model did not honor them reliably (M2).
2026-10-15: M2 passed: 34/34 cleanup cases, median 0.39 s end-of-speech to text, no stray hotkey input, rich paste correct. Qwen 3.5 4B retained; 8B not needed.
2026-10-15: Models are downloaded from pinned Hugging Face revisions and verified against SHA-256 checksums before use. Why: PRD R40, supply-chain safety.
