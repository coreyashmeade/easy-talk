# M3 Results: Core Loop

2026-10-15. All P0 requirements built. Verified with the app's built-in self-test (`EasyTalk --selftest`), which runs the production pipeline on synthesized speech, plus manual use on the reference machine.

## Automated checks

| Check | Requirement | Result |
|---|---|---|
| Cleanup and safety test set | R13–R15, R17, R18, R36–R38 | 33/33 pass; median 0.36 s, max 0.76 s |
| Long dictation | G3 | 75 s of speech processed in 1.98 s (target: 2 s for 30 s) |
| Clipboard restore | R23 | Rich and plain text present during paste; prior clipboard restored |
| Checksum verification | R40 | Genuine model file accepted; tampered copy rejected |
| No network | R39 | No connections from the app or self-test during the run |
| No audio on disk | R41 | No audio files written by the app |

Run it:
```bash
"app/build/Easy Talk.app/Contents/MacOS/EasyTalk" --selftest tests/cleanup-cases.json
```

## Manual checks
- Setup completed: permissions, engine choice, model verification and load, practice dictation.
- Dictation pasted into the setup practice box and into the Claude desktop app. After Easy Talk enables its accessibility tree, Claude reports its message field directly (AXTextArea).
- Paste verified in the target apps: Gmail, Claude and ChatGPT.
- Apple speech engine: selected from the menu bar, loaded in 69 ms; dictations transcribed in 143–190 ms and pasted within 0.7 s of release.
- Hotkey behavior (hold, double-tap lock, Esc, no stray spaces, multi-display pill) carried over from the M2 prototype.

## Issues found and fixed
- **Models failed to load:** Parakeet was stored under a folder name FluidAudio doesn't use. The folder name now comes from FluidAudio, and setup only continues once both models load.
- **No paste into Easy Talk's own windows:** as a menu bar app it had no Edit menu, so ⌘V never reached its fields. Added a standard Edit menu; when Easy Talk is frontmost, it pastes directly.
- **Copied instead of pasted in Electron apps:** apps like Claude don't report their focused text field by default. Easy Talk now asks them to, and pastes whenever the frontmost app has a window.

## Not verified
- Offline dictation with Wi-Fi off (the self-test confirms no network connections are made). Slack and Google Docs were removed from the target apps.
