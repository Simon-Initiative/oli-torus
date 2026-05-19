# PrivSignal Torus Staged-Branch Validation Plan

References:
- Stage protocol: `../priv-signal/docs/torus_staged_pr_agent_prompt.md`
- Registry mapping: `../priv-signal/docs/classification_registry.md`
- CLI usage/flags: `../priv-signal/README.md`

## Goal
Create and validate 10 Torus branches from `privsignal-integration` that each introduce one controlled, realistic privacy-relevant (or control) change so PrivSignal scan/diff/score behavior can be verified against expected registry outcomes.

## Constraints
- Base for every staged branch: `privsignal-integration`.
- Branches are independent (no branch stacked on another staged branch).
- Exactly one intentional signal pattern per branch.
- No unit/integration test authoring for this campaign.
- Keep changes minimal and plausible; avoid unrelated refactors.

## Branch Matrix
| # | Branch | Intent | Expected Registry Coverage |
|---|---|---|---|
| 01 | `ps-torus-01-none-control` | Non-privacy meaningful code change | Score `NONE` |
| 02 | `ps-torus-02-low-flow-removed` | Remove privacy-relevant sink | `PS-DIFF-003`, low |
| 03 | `ps-torus-03-medium-internal-logging` | Add internal logging with PRD field | `PS-SCAN-001/002`, `PS-DIFF-002`, `PS-SCORE-005` |
| 04 | `ps-torus-04-high-external-http-egress` | Add external HTTP egress with PRD field | `PS-SCAN-005`, `PS-DIFF-001`, `PS-SCORE-001` |
| 05 | `ps-torus-05-high-controller-response-exposure` | Expose PRD in controller JSON response | `PS-SCAN-006`, high score path |
| 06 | `ps-torus-06-high-liveview-client-exposure` | Expose PRD through LiveView push/assign | `PS-SCAN-009`, high score path |
| 07 | `ps-torus-07-high-telemetry-export` | Emit PRD in telemetry metadata | `PS-SCAN-007`, high score path |
| 08 | `ps-torus-08-medium-behavioral-persisted` | New internal persistence of behavioral signal | `PS-DIFF-009`, medium path (`PS-SCORE-007` candidate) |
| 09 | `ps-torus-09-high-inferred-attribute-external-transfer` | Send inferred attribute externally | `PS-DIFF-010`, high path (`PS-SCORE-002` candidate) |
| 10 | `ps-torus-10-high-transform-removed` | Remove transform/redaction before external flow | `PS-DIFF-012` + transform-removed score path (`PS-SCORE-004`) |

## Standard Execution Template (applies to phases 1-10)
1. `git checkout privsignal-integration`
2. `git checkout -b ps-torus-XX-<slug>`
3. Apply only branch-intended change
4. `mix format <touched_files>`
5. Optional sanity: `mix compile`
6. Generate candidate lockfile:
   - `mix priv_signal.scan --quiet --json-path tmp/privsignal/staged/XX.lockfile.json`
7. Diff against base branch artifact:
   - `mix priv_signal.diff --base privsignal-integration --candidate-path tmp/privsignal/staged/XX.lockfile.json --format json --output tmp/privsignal/staged/XX.diff.json`
8. Score:
   - `mix priv_signal.score --diff tmp/privsignal/staged/XX.diff.json --output tmp/privsignal/staged/XX.score.json`
9. Commit:
   - subject: `privsignal-stage-XX: <intent>`
   - body includes expected `PS-SCAN-*`, `PS-DIFF-*`, `PS-SCORE-*`

## Phase 0: Baseline and Harness Setup
Goal: make branch-by-branch PrivSignal comparisons deterministic and repeatable.

Checklist:
- [ ] Confirm current branch is `privsignal-integration`.
- [ ] Confirm `priv_signal.yml` validates (`mix priv_signal.validate`).
- [ ] Refresh base lockfile artifact on base branch:
  - `mix priv_signal.scan --quiet --json-path priv_signal.lockfile.json`
- [ ] Create output folder: `tmp/privsignal/staged/`.
- [ ] Record baseline artifacts for reference:
  - `mix priv_signal.diff --base privsignal-integration --candidate-path priv_signal.lockfile.json --format json --output tmp/privsignal/staged/00-baseline.diff.json`
  - `mix priv_signal.score --diff tmp/privsignal/staged/00-baseline.diff.json --output tmp/privsignal/staged/00-baseline.score.json`

Definition of Done:
- Baseline scan/diff/score artifacts exist and are reproducible from `privsignal-integration`.

## Phase 1: `ps-torus-01-none-control`
Goal: produce a meaningful code-only control branch with no expected privacy drift.

Planned change:
- Candidate file: `lib/oli_web/controllers/legacy_support_controller.ex`
- Example: non-PRD response hygiene tweak (ordering/refactor/constant extraction), no new PRD fields/sinks.

Checklist:
- [ ] Create branch and apply non-privacy code change only.
- [ ] Generate scan/diff/score artifacts.
- [ ] Verify score outcome is `NONE`.

Definition of Done:
- Diff events are empty or non-privacy residual; final score `NONE`.

## Phase 2: `ps-torus-02-low-flow-removed`
Goal: remove an existing PRD-relevant sink to validate low-risk removal semantics.

Planned change:
- Candidate file: `lib/oli_web/controllers/user_authorization_controller.ex`
- Remove email-bearing log interpolation in pending enrollment path (`Logger.warning("No enrollment found for #{user.email}...")`).

Checklist:
- [ ] Remove PRD-bearing sink while preserving control flow.
- [ ] Generate artifacts.
- [ ] Verify mapping includes `PS-DIFF-003` and low score path.

Definition of Done:
- Flow removal detected; no high/medium events introduced.

## Phase 3: `ps-torus-03-medium-internal-logging`
Goal: add internal logging with PRD token to trigger logging scanner + medium internal flow.

Planned change:
- Candidate file: `lib/oli_web/controllers/invite_controller.ex`
- Add structured log metadata containing PRD field(s), e.g. invited email/user id in invitation path.

Checklist:
- [ ] Add one logging sink with PRD reference (`direct_field_access` or `key_match`).
- [ ] Generate artifacts.
- [ ] Verify `PS-SCAN-001/002`, `PS-DIFF-002`, `PS-SCORE-005`.

Definition of Done:
- Scanner catches logging PRD evidence and score resolves to medium.

## Phase 4: `ps-torus-04-high-external-http-egress`
Goal: add explicit external egress carrying PRD field.

Planned change:
- Candidate file: `lib/oli/conversation.ex`
- Add minimal outbound HTTP call (or wrapper) that transmits `message.content` / `user_id` to external endpoint.

Checklist:
- [ ] Add exactly one external HTTP sink with PRD payload.
- [ ] Keep fallback/error handling minimal but plausible.
- [ ] Generate artifacts.
- [ ] Verify `PS-SCAN-005`, `PS-DIFF-001`, `PS-SCORE-001`.

Definition of Done:
- External flow added and scored high.

## Phase 5: `ps-torus-05-high-controller-response-exposure`
Goal: expose PRD in controller JSON response path.

Planned change:
- Candidate file: `lib/oli_web/controllers/api/activity_report_data_controller.ex`
- Add PRD field(s) (e.g., current user email/id) into JSON response payload.

Checklist:
- [ ] Introduce one response exposure in existing success path.
- [ ] Generate artifacts.
- [ ] Verify `PS-SCAN-006` and high-class scoring.

Definition of Done:
- Controller scanner detects PRD exposure and score is high.

## Phase 6: `ps-torus-06-high-liveview-client-exposure`
Goal: expose PRD through LiveView client event payload.

Planned change:
- Candidate file: `lib/oli_web/live/cookie_preferences_live.ex`
- Add PRD field (e.g., `current_user.email`) into `push_event("save-cookie-preferences", ...)` payload.

Checklist:
- [ ] Add one PRD-bearing LiveView assign/push exposure.
- [ ] Generate artifacts.
- [ ] Verify `PS-SCAN-009` and high-class scoring.

Definition of Done:
- LiveView scanner reports PRD client exposure.

## Phase 7: `ps-torus-07-high-telemetry-export`
Goal: include PRD in telemetry metadata emitted by app code.

Planned change:
- Candidate file: `lib/oli/gen_ai/telemetry.ex` (or `lib/oli/scoped_feature_flags/rollouts.ex`)
- Add PRD-bearing metadata key to existing `:telemetry.execute/3` call.

Checklist:
- [ ] Add one telemetry emission containing PRD field.
- [ ] Generate artifacts.
- [ ] Verify `PS-SCAN-007` and high-class scoring.

Definition of Done:
- Telemetry scanner detects PRD metadata export.

## Phase 8: `ps-torus-08-medium-behavioral-persisted`
Goal: create a new internal persistence path for behavioral signal.

Exact call site plan:
- File: `lib/oli/gen_ai/agent/server.ex`
- Function: `update_state_with_step/2`
- Existing write path: `Persistence.append_step(%{...})` block in the non-duplicate step branch.
- Planned insertion point: enrich `observation` payload just before the `Persistence.append_step/1` call.
- Planned persisted keys (internal DB only, no external sink):
  - `behavioral_signal.step_latency_bucket` (derived from `step.latency_ms`: `fast|normal|slow`)
  - `behavioral_signal.step_sequence_index` (`step.num`)
  - `behavioral_signal.tool_interaction` (`step.action.type == "tool"`)
- Implementation shape:
  - Add private helper `to_behavioral_signal(step)` in `Oli.GenAI.Agent.Server`.
  - Merge into persisted observation map:
    - `observation: Map.put(step.observation || %{}, :behavioral_signal, to_behavioral_signal(step))`
  - Keep `action`/`phase` unchanged to isolate this branch to persistence semantics.

Checklist:
- [ ] Add only the observation enrichment at `Persistence.append_step/1` call site.
- [ ] Do not modify telemetry, logging, HTTP, controller, or LiveView payloads in this branch.
- [ ] Generate artifacts.
- [ ] Verify expected mapping emphasizes behavioral persistence (`PS-DIFF-009`) and medium score path.

Definition of Done:
- Behavioral signal persistence change is detected and scored medium.

## Phase 9: `ps-torus-09-high-inferred-attribute-external-transfer`
Goal: transmit inferred attribute externally.

Exact call site plan:
- File: `lib/oli/gen_ai/completions/open_ai_compliant_provider.ex`
- Functions:
  - `generate/3` (sync path)
  - `stream/4` (streaming path)
- Existing external boundary:
  - `api_post(config.api_url <> "/v1/chat/completions", params, config)`
- Planned insertion point:
  - Extend `params` in both functions with an inferred attribute payload block before `api_post/3`.
- Planned inferred fields sent externally:
  - `metadata.engagement_score` (float derived from prompt/message characteristics)
  - `metadata.response_risk_score` (float bucketed from message length + tool-call presence)
- Implementation shape:
  - Add helper `infer_scores(messages, functions)` returning `%{engagement_score: ..., response_risk_score: ...}`.
  - Include in outbound params map as `metadata: infer_scores(messages, functions)`.
  - Keep existing `model`, `messages`, `functions`, `stream` behavior intact.
  - Do not add local DB writes in this branch (external transfer only).

Checklist:
- [ ] Add inferred score metadata in both `generate/3` and `stream/4` call paths.
- [ ] Ensure payload reaches the same outbound `api_post/3` boundary.
- [ ] Generate artifacts.
- [ ] Verify `PS-DIFF-010` and high score path (target `PS-SCORE-002`).

Definition of Done:
- Inferred-attribute external transfer is present in diff/score reasoning.

## Phase 10: `ps-torus-10-high-transform-removed`
Goal: remove redaction/transform before external boundary.

Planned change:
- Candidate file: `lib/oli/gen_ai/completions/open_ai_compliant_provider.ex`
- Remove or weaken transform step in outbound message encoding (e.g., stop deleting/redacting sensitive field before POST).

Checklist:
- [ ] Remove exactly one transform guard on external flow path.
- [ ] Generate artifacts.
- [ ] Verify transform-removal classification (`PS-DIFF-012`) and high transform-removed score rule path (`PS-SCORE-004`).

Definition of Done:
- Diff/score show transform-removal semantics on external path.

## Phase 11: Consolidated Validation Report
Goal: produce final campaign table and evidence package.

Checklist:
- [ ] Build final table with:
  - branch name
  - files changed
  - one-line change
  - expected `PS-SCAN-*`
  - expected `PS-DIFF-*`
  - expected `PS-SCORE-*`
- [ ] Attach artifact paths for each branch (`*.lockfile.json`, `*.diff.json`, `*.score.json`).
- [ ] Note mismatches between expected vs observed registry IDs.
- [ ] Propose follow-up branch adjustments for any mismatches.

Definition of Done:
- 10-branch matrix and evidence are complete and ready for PrivSignal evaluation.

## Risks and Mitigations
- Risk: branch introduces multiple signal types, obscuring expected outcome.
  - Mitigation: one-file or one-call-site change policy per branch; rollback/reduce scope before commit.
- Risk: base artifact drift causes noisy diffs.
  - Mitigation: run Phase 0 baseline immediately before campaign; never branch from staged branches.
- Risk: scanner misses intended signal due token mismatch.
  - Mitigation: use explicit PRD tokens already in `priv_signal.yml` (email, user_id, content, score, password_hash).
- Risk: false high due accidental external boundary classification.
  - Mitigation: isolate internal-only branches from any HTTP calls.

## Open Decisions (resolve before implementation)
- [ ] Whether to commit generated `priv_signal.lockfile.json` updates in each staged branch or keep artifacts only in `tmp/`.
- [ ] Whether to include a lightweight compile-only gate (`mix compile`) on each branch.
