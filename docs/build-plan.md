# Easy Talk Build
Project Plan

**Summary:** Deliver Easy Talk v1 to the approved PRD and design: risk checks first, core loop by October 24, full v1 by October 31, and a two-week daily-use review by November 17.

## Context & Links
- **Source:** PRD (`docs/prd.md`, approved 2026-10-14) and design (`docs/design/`, approved 2026-10-15)
- **Owner:** Corey Ashmeade
- **Status:** In flight. M0 to M2 complete; M3 in progress.
- **Repo:** [github.com/coreyashmeade/easy-talk](https://github.com/coreyashmeade/easy-talk) (private)

## Objective & Success Criteria
**Objective:** a daily-use Mac dictation tool that turns speech into clean, formatted text entirely on-device.

**Success criteria**
- Every PRD acceptance criterion passes on the reference machine.
- Median time from releasing the hotkey to pasted text is 2 seconds or less for a 30-second dictation.
- Lists and paragraphs paste correctly in Slack, Gmail, Google Docs, Claude and ChatGPT.
- No network connections after the one-time model download.
- Easy Talk is the primary dictation tool on 10 of the first 14 days.

## Scope & Deliverables
- Risk checks for hotkey capture, speed and quality, and rich-text paste.
- A cleanup test set with an automated runner.
- The core loop: hotkey, record, transcribe, clean up, safety check, paste.
- The recording pill (all states), menu bar menu, settings and first-run setup.
- Apple speech as a second engine, plus the P1 features.
- README with build, run and permission-reset steps.

**Out of scope:** see PRD Non-Goals.

## Milestones & Timeline

| # | Milestone | Target | Status | Done when |
|---|-----------|--------|--------|-----------|
| M0 | Build environment ready | 2026-10-16 | Done 2026-10-15 | Xcode 27 installed; command-line builds work. |
| M1 | Groundwork | 2026-10-17 | Done 2026-10-15 | Licenses reviewed; stable code signing so permissions survive rebuilds; cleanup test set written. |
| M2 | Risk checks | 2026-10-20 | Done 2026-10-15 | Hotkey, speed/quality and rich paste proven with prototypes (`docs/m2-results.md`). |
| M3 | Core loop (P0) | 2026-10-24 | In progress | All P0 acceptance criteria pass. |
| M4 | v1 complete (P1) | 2026-10-31 | Not started | All PRD acceptance criteria pass; UI matches the design. |
| M5 | Daily-use review | 2026-11-17 | Not started | Two weeks of use; issues logged; go/no-go on fixes and a public release. |

M2 gated M3: no full build until the hotkey, model and paste approaches were proven.

## Risks, Assumptions & Mitigations
- **Risk:** the cleanup model rewords too much or responds to dictated instructions. **Mitigation:** test set, PRD safety fallback (R38), 8B upgrade path. M2: 34/34 cases pass.
- **Risk:** macOS re-prompts for permissions after each rebuild. **Mitigation:** stable Apple Development signing. Confirmed in M2.
- **Risk:** rich-text paste renders differently per app. **Mitigation:** HTML + RTF + plain text on the clipboard; per-app check in M3.
- **Assumption:** a free Apple Developer team is sufficient for personal use; a paid account is needed only for a signed public release.

## Open Questions
- Public release after M5? Needed by 2026-11-17. Requires a paid Apple Developer account, a name check, a privacy note and the MIT license.
- Keep or retire the Figma copy of the design (out of date since 2026-10-15)?

---
*Easy Talk • Project Plan • Owner: Corey Ashmeade*
