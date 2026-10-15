# Easy Talk Build
Project Plan

**Summary:** Deliver Easy Talk as a proof of concept to the approved PRD and design: risk checks first, then the core loop. Delivered 2026-10-15.

## Context & Links
- **Source:** PRD (`docs/prd.md`, approved 2026-10-14) and design (`docs/design/`, approved 2026-10-15)
- **Owner:** Corey Ashmeade
- **Status:** Complete (2026-10-15). M0 to M3 delivered; M4 and M5 dropped to close the project as a proof of concept.
- **Repo:** [github.com/coreyashmeade/easy-talk](https://github.com/coreyashmeade/easy-talk) (private)

## Objective & Success Criteria
**Objective:** a working on-device dictation proof of concept that turns speech into clean, formatted text.

**Success criteria (results 2026-10-15)**
- P0 requirements built and verified: met (`docs/m3-results.md`).
- 2 seconds or less from release to text for a 30-second dictation: met (75 s of speech in 1.98 s).
- No network connections after the model download: met.
- Lists and paragraphs paste correctly in the target apps (Gmail, Claude, ChatGPT): met.

## Scope & Deliverables
- Risk checks for hotkey capture, speed and quality, and rich-text paste.
- A cleanup test set with an automated runner.
- The core loop: hotkey, record, transcribe, clean up, safety check, paste.
- The recording pill (all states), menu bar menu, settings and first-run setup.
- Apple speech as a second engine.
- README with build, run, self-test and permission-reset steps.

**Out of scope:** see PRD Non-Goals.

## Milestones & Timeline

| # | Milestone | Target | Status | Done when |
|---|-----------|--------|--------|-----------|
| M0 | Build environment ready | 2026-10-16 | Done 2026-10-15 | Xcode 27 installed; command-line builds work. |
| M1 | Groundwork | 2026-10-17 | Done 2026-10-15 | Licenses reviewed; stable code signing so permissions survive rebuilds; cleanup test set written. |
| M2 | Risk checks | 2026-10-20 | Done 2026-10-15 | Hotkey, speed/quality and rich paste proven with prototypes (`docs/m2-results.md`). |
| M3 | Core loop (P0) | 2026-10-24 | Done 2026-10-15 | All P0 requirements built; automated checks pass (`docs/m3-results.md`). |
| M4 | v1 complete (P1) | 2026-10-31 | Dropped | P1 requirements deferred (see PRD status). |
| M5 | Daily-use review | 2026-11-17 | Dropped | Not needed for a proof of concept. |

M2 gated M3: no full build until the hotkey, model and paste approaches were proven.

## Risks, Assumptions & Mitigations
- **Risk:** the cleanup model rewords too much or responds to dictated instructions. **Mitigation:** test set, PRD safety fallback (R38), 8B upgrade path. M2: 34/34 cases pass.
- **Risk:** macOS re-prompts for permissions after each rebuild. **Mitigation:** stable Apple Development signing. Confirmed in M2.
- **Risk:** rich-text paste renders differently per app. **Mitigation:** HTML + RTF + plain text on the clipboard. Verified in Gmail, Claude and ChatGPT.
- **Assumption:** a free Apple Developer team is sufficient for personal use; a paid account is needed only for a signed public release.

## Open Questions
- Public release: not planned. Would require a paid Apple Developer account, notarization, a name check, a privacy note, an MIT `LICENSE` and a test on a fresh macOS account.
- Figma copy of the design is out of date; the canvas and `docs/design/` are the reference.

---
*Easy Talk • Project Plan • Owner: Corey Ashmeade*
