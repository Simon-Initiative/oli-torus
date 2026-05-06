# Progress — email_sending (MER-5257)

Live status of the work. Edit this file as items complete; the live page at `/dev/mer-5257` reads it on each click. Detailed task content lives in `plan.md`; this file is the at-a-glance tracker.

- Jira: [MER-5257](https://eliterate.atlassian.net/browse/MER-5257)
- Plan (full detail): [plan.md](plan.md)
- PRD: [prd.md](prd.md)
- Requirements: [requirements.yml](requirements.yml)
- Open gaps: [gaps.md](gaps.md)
- Figma node: https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=955-17500

## Current Status

- **Phase:** Phase 0 complete; ready to start Phase 1 (Backend Domain Services)
- **Last updated:** 2026-05-05
- **Next step:** begin Phase 1 step 1.1 — Situation enum + lookup map module
- **Branch:** `MER-5257-ai-email-capabilities-updates` (pushed; draft PR open)

## Status legend

- `[ ]` not started
- `[~]` in progress
- `[x]` complete

## Requirements coverage (from `requirements.yml`)

| FR | Title | Status |
|----|-------|--------|
| FR-001 | Capture normalized initiation context | [ ] |
| FR-002 | Stable situation contract | [ ] |
| FR-003 | Initial AI draft on modal open w/ neutral tone | [ ] |
| FR-004 | Editable subject and body (incl. body vertical scroll AC-016) | [ ] |
| FR-005 | Tone selection state-only until regenerate | [ ] |
| FR-006 | Regenerate replaces, preserves recipients | [ ] |
| FR-007 | Chip prefill + manual recipient add | [ ] |
| FR-008 | Block invalid send | [ ] |
| FR-009 | Whitelist placeholder substitution | [ ] |
| FR-010 | One Oban job per recipient | [ ] |
| FR-011 | Recoverable failures | [ ] |
| FR-012 | Modal accessibility behavior | [ ] |
| FR-013 | GenAI Feature Config "Instructor Email" | [ ] |
| FR-014 | Hyperlink insert/edit in body | [ ] |
| FR-015 | Send-time placeholder validation | [ ] |

## Phases & Steps

### Phase 1 — Backend Domain Services

- [ ] 1.1 — Situation enum + lookup map
- [ ] 1.2 — Context builder service
- [ ] 1.3 — AI draft facade
- [ ] 1.4 — Prompt composer
- [ ] 1.5 — GenAI Feature Config "Instructor Email"

### Phase 2 — Placeholder Substitution + Send Pipeline

- [ ] 2.1 — Whitelist substitution module
- [ ] 2.2 — Per-recipient template realization
- [ ] 2.3 — Oban worker (one job per recipient)
- [ ] 2.4 — Send-time placeholder validation
- [ ] 2.5 — Per-recipient result summary

### Phase 3 — Figma / UI Workflow Alignment ✅

- [x] 3.1 — Run `ui_workflow` against Figma node 955:17500 (equivalent design context + screenshot + variable defs fetched, brief embedded in `gaps.md` decisions)
- [x] 3.2 — Resolve B2 design state gaps (G-D01..G-D14) — all 14 RESOLVED
- [x] 3.3 — Resolve B3 token drift (G-T01..G-T03) — all 3 RESOLVED

### Phase 4 — Reusable Draft Email Modal (UI + a11y)

- [ ] 4.1 — LiveComponent state model
- [ ] 4.2 — Recipient chip pills + remove + manual add
- [ ] 4.3 — Tone buttons (Neutral / Encouraging / Firm)
- [ ] 4.4 — Subject input
- [ ] 4.5 — Body textarea + scroll + hyperlink editor
- [ ] 4.6 — Generate / Send / Cancel buttons
- [ ] 4.7 — Focus trap + keyboard ops
- [ ] 4.8 — Loading / error / empty / validation states
- [ ] 4.9 — Live region announcements
- [ ] 4.10 — Smoke harness page

### Phase 5 — Entry-Point Integrations

- [ ] 5.1 — Student Support tile launcher
- [ ] 5.2 — Assessments tile launcher
- [ ] 5.3 — Student Overview launcher
- [ ] 5.4 — Content → Student list launcher
- [ ] 5.5 — Learning Objectives → Student list launcher
- [x] 5.6 — Additional entry points (G-J01 resolved: closed list = the 5 explicit entry points)
- [ ] 5.7 — "Email sent" banner

### Phase 6 — End-to-End Verification + Manual QA

- [ ] 6.1 — Targeted test suites
- [ ] 6.2 — Telemetry verification
- [ ] 6.3 — Manual keyboard walkthrough
- [ ] 6.4 — Screen-reader verification
- [ ] 6.5 — Context-quality entry-point spot checks
- [ ] 6.6 — Banner placement verified
- [ ] 6.7 — `mix format` + lints
- [ ] 6.8 — `requirements.yml` proofs updated
- [ ] 6.9 — Review notes prepared

## PR split

- [ ] PR 1 — Backend domain (Phase 1)
- [ ] PR 2 — Send pipeline (Phase 2)
- [ ] PR 3 — Modal LiveComponent (Phases 3, 4)
- [ ] PR 4 — Entry points + final verification (Phases 5, 6)

## Gap status (from `gaps.md`)

| Section | Owner | Open | Proposed | Asked | Answered | Resolved | Total |
|---------|-------|------|----------|-------|----------|----------|-------|
| B1 — Jira scope (Jess + Darren) | Jess / Darren | 0 | 0 | 0 | 0 | 12 | 12 |
| B2 — Figma design states (design) | design team | 0 | 0 | 0 | 0 | 14 | 14 |
| B3 — Token drift (design) | design team | 0 | 0 | 0 | 0 | 3 | 3 |

Update these counts as `gaps.md` items move through statuses.

## Session History

### Session 1 — 2026-05-04
- Fetched Jira ticket + 3 comments.
- Fetched Figma node `955:17500` (dark variant only).
- Token mapping completed; identified DR1/DR2/DR3 drift.
- Confirmed prior-art folder `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/` already contains `informal.md`, `prd.md`, `requirements.yml`.
- Verified PRD/requirements coverage vs Jira+comments; found 4 transcription gaps (PRD-G1..G4).
- Wrote `gaps.md` with 29 open decisions across B1/B2/B3.
- Updated `prd.md` and `requirements.yml` to capture PRD-G1..G4 (added FR-013, FR-014, FR-015, AC-016).
- Built dev LiveView at `/dev/mer-5257` for live doc viewing.
- Wrote `plan.md` (six phases, four PRs) and this `progress.md`.

### Session 2 — 2026-05-05
- Closed all B1 gaps via codebase research + parallel agents + user decisions:
  - G-J01 (entry points) RESOLVED via codebase exhaustive scan — 5 entry points confirmed.
  - G-J02 (situation enum) RESOLVED — 7 keys derived from existing tile projectors.
  - G-J03 (EmailContext field shape) RESOLVED — fields derived from existing projector @types.
  - G-J04 (partial-fail policy) RESOLVED — send valid + notify failures; no retry UI in v1.
  - G-J05 (required fields) RESOLVED — recipients > 0 + non-empty subject + non-empty body.
  - G-J06 (recipient cap) RESOLVED — env var `INSTRUCTOR_EMAIL_MAX_RECIPIENTS` default 100, fail-closed.
  - G-J11 (feature flag) RESOLVED — no flag (trust PRD §11).
  - G-J12 (AI quota) RESOLVED — Option C, defer per-section quota.
- Reverted G-J07 (manual recipients) after finding `EmailList` precedent; surfaced to Jess; she answered: section-enrolled students only.
- Closed all B2 gaps:
  - G-D01 (light mode) verified missing in Figma; resolved via token-system insight (Tailwind tokens carry both light + dark variants).
  - G-D02..G-D14 RESOLVED via parallel agent research; reused existing patterns (button primitives, `summary_tile` AI spinner, `student_support_parameters_modal` validation banner, `OverflowChipList`, base modal Cancel pattern, Slate `RichTextEditor`).
- Closed all B3 token drift gaps:
  - G-T01 RESOLVED — add new token `Fill-Buttons-fill-primary-bold` (#0062F2), do not overwrite existing.
  - G-T02 RESOLVED — scrollbar drift, browser-managed, ignore.
  - G-T03 RESOLVED — light value used cross-mode for scrollbar contrast, no token change.
- Confirmed via Slack with Jess: G-J07 enrolled-only, G-J08 interim copy approved, G-D05 banner pattern + resolver fallback approved, G-D09 Slate-restricted approach.
- Updated `prd.md`, `requirements.yml`, `plan.md`, `gaps.md`, this file.
- Committed Phase 0 artifacts as `[FEATURE] [MER-5257] Add Phase 0 planning docs and dev doc viewer` (`82f99e0ae4`).
- Pushed branch + opened draft PR.
- **Next:** begin Phase 1.1 — Situation enum + lookup map module, following the closed list of 7 situation keys from G-J02.
