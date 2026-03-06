# PrivSignal Staged Branch Validation Report

Date: 2026-03-05
Base branch: `privsignal-integration`

## Run Scope
This report reflects a full rerun of the first 10 staged branches after syncing `priv_signal.yml` across branches and refreshing the baseline lockfile on `privsignal-integration`, plus an additional targeted branch-11 run to exercise scanner improvements (fuzzy matching, DB wrappers, HTTP provenance). For each branch, we regenerated:
- `tmp/privsignal/staged/XX.lockfile.json`
- `tmp/privsignal/staged/XX.diff.json`
- `tmp/privsignal/staged/XX.score.json`

## Current Results
| # | Branch | Commit | File Changed | Intended Score | Observed Score | Diff Events |
|---|---|---|---|---|---|---|
| 01 | `ps-torus-01-none-control` | `ff31e6cc7a` | `lib/oli_web/controllers/legacy_support_controller.ex` | `NONE` | `NONE` | 0 |
| 02 | `ps-torus-02-low-flow-removed` | `a7557409cd` | `lib/oli/automation_setup.ex` | `LOW` | `LOW` | 40 |
| 03 | `ps-torus-03-medium-internal-logging` | `e6faf6a55d` | `lib/oli_web/controllers/invite_controller.ex` | `MEDIUM` | `MEDIUM` | 73 |
| 04 | `ps-torus-04-high-external-http-egress` | `91fb4ccf85` | `lib/oli/conversation.ex` | `HIGH` | `HIGH` | 42 |
| 05 | `ps-torus-05-high-controller-response-exposure` | `4978b0ceba` | `lib/oli_web/controllers/api/activity_report_data_controller.ex` | `HIGH` | `HIGH` | 42 |
| 06 | `ps-torus-06-high-liveview-client-exposure` | `763c52b874` | `lib/oli_web/live/cookie_preferences_live.ex` | `HIGH` | `HIGH` | 40 |
| 07 | `ps-torus-07-high-telemetry-export` | `1dcc5dc548` | `lib/oli/gen_ai/telemetry.ex` | `HIGH` | `HIGH` | 40 |
| 08 | `ps-torus-08-medium-behavioral-persisted` | `dcc87b6bfe` | `lib/oli/gen_ai/agent/server.ex` | `MEDIUM` | `MEDIUM` | 51 |
| 09 | `ps-torus-09-high-inferred-attribute-external-transfer` | `f7902538b3` | `lib/oli/gen_ai/completions/open_ai_compliant_provider.ex` | `HIGH` | `HIGH` | 12 |
| 10 | `ps-torus-10-high-transform-removed` | `b2a430e68d` | `lib/oli/gen_ai/completions/open_ai_compliant_provider.ex` | `HIGH` | `HIGH` | 44 |
| 11 | `ps-torus-11-high-improvements-coverage` | `77911074a7` | `lib/oli_web/controllers/invite_controller.ex` | `HIGH` | `HIGH` | 89 |

## Outcome Summary
- Control branch `01` now resolves to `NONE`.
- Medium-path branches `03` and `08` resolve to `MEDIUM`.
- High-path branches `04`, `05`, `06`, `07`, `09`, and `10` resolve to `HIGH`.
- Branch `02` was revised to an isolated internal sink removal and now resolves to `LOW`.
- Branch `11` exercises scanner improvements (fuzzy identifier mapping, inherited DB wrapper evidence, HTTP payload provenance) and resolves to `HIGH`.

## Artifacts
Artifacts for the rerun are located at:
- `tmp/privsignal/staged/01.lockfile.json` ... `tmp/privsignal/staged/11.lockfile.json`
- `tmp/privsignal/staged/01.diff.json` ... `tmp/privsignal/staged/11.diff.json`
- `tmp/privsignal/staged/01.score.json` ... `tmp/privsignal/staged/11.score.json`
- `tmp/privsignal/staged/rerun_results.tsv`

## Scanner Limitations That Required Workarounds
1. `PRD token matching is literal, not fuzzy`
- Scanner evidence is built from literal PRD field tokens and direct field access (for example `user.email`, key `email`, key `user_id`).
- Names like `submitted_emails`, `invitee_emails`, or arbitrary variable names do not map unless they exactly match configured PRD tokens.

2. `Database scanner is callsite-driven on literal Repo operations`
- Database read/write detection keys off direct `Repo.*` callsites (for example `Repo.insert`, `Repo.insert_all`, `Repo.update`).
- Wrapper calls (for example `Persistence.append_step(...)`) are not treated as DB sinks by the scanner unless the direct `Repo.*` call is visible at the scanned callsite.

3. `HTTP scanner requires recognized module call + PRD evidence present in sink arguments`
- HTTP sink detection looks for explicit remote module calls (for example `HTTPoison.post(...)`, `Req.post(...)`, etc.).
- PRD linkage is extracted from the HTTP call arguments AST. If payload content is hidden behind prebuilt/encoded variables (or otherwise not present in the sink argument structure), `data_refs` can be empty and the flow may not classify.
