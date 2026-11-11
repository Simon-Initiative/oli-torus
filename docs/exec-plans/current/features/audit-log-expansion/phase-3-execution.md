# Phase 3 Execution Record

Work item: `docs/exec-plans/current/features/audit-log-expansion`
Phase: `3` (MER-6113, PR-03), design `design/pr-03-identity-and-platform-administration.md`

## Scope from plan.md
- Coverage for identity and platform administration: accounts, access, provisioning, authentication and recovery, organizations and consent, LMS/SSO/LTI and external tools, AI services, API/MCP credentials, feature flags and rollouts.
- Current authorization: checkpoint A, then pause for owner review. No commits or publication authorized.
- Branch: `sub-task/MER-6113-audit-log-coverage-identity-and-platform-administration`, created from PR-02's last commit `ab1bae4434`; not pushed.

## Implementation Blocks
- [x] Design approved by the owner on 2026-11-11, with two decisions: bulk community membership keeps per-target partial success, and declining a pending LMS registration request is audited.
- [x] Checkpoint A implementation (2026-11-11), owner review pending:
  - `Oli.Accounts.Audited` gained `delete_author/2`, `admin_update_user/3`, `admin_update_author/3`, `lock_account/3`, `unlock_account/3`, `admin_confirm_email/2`, `sync_platform_roles/3`, and `update_own_profile/3`, each with its `*_multi/4` variant where callers compose it. Updates lock the row `FOR UPDATE`, diff before and after under the account field policy, and write one event per event type with changes, sharing the context's operation ID. A write that changes nothing writes no event.
  - `Mutations` generalized to `delete_account/1` and gained `update_account/1` and `put_platform_roles/2`.
  - `Oli.Accounts.ProtectedKeys` adds a `:protected` error for any schema field outside a command's allowlist. `User.unprotected_changeset/2` (state, `research_opt_out`, preferences) and `Author.unprotected_changeset/2` (preferences) back the restricted `Accounts.update_user/2` and `Accounts.update_author/2`.
  - Removed from `Oli.Accounts`: `delete_author/1`, `admin_update_author/3`, `lock_user/1`, `unlock_user/1`, `lock_author/1`, `unlock_author/1`, `admin_confirm_user/1`, `admin_confirm_author/1`, `update_user_platform_roles/2`. `link_user_author_account/2` and `unlink_user_author_account/1` write with `noauth_changeset/2` until checkpoint B migrates linking.
  - Callers: user and author detail views (confirm, lock, unlock, delete, submit; the manual `account_internal_flag_changed` and `author_deleted` captures are removed), collaborator invitation cleanup (`delete_author_multi/4` merged into its Multi), both settings pages (`update_own_profile/3`), LTI launch (`sync_platform_roles_multi/4` inside the launch transaction under `provider_provisioning`), open-and-free enrollment and join (`sync_platform_roles/3` with the user as actor; the result stays ignored, as before).
  - Catalog: `platform_roles` pseudo key in `Fields.user_account/0` and the `User` schema source; `account_permissions_changed` admits the system actor.
  - Design reconciled: the system-admin rule for roles and the internal flag stays in the author detail view; platform roles are a `set` change of sorted URIs; `update_own_profile/3` also accepts `name`.
- [ ] Checkpoint B: provisioning, profile, linking, recovery, Scenarios.
- [ ] Checkpoint C: sessions.
- [ ] Checkpoint D: organizations, consent, integrations.
- [ ] Checkpoint E: AI services, credentials, flags.
- [ ] Checkpoint F: final verification.

## Test Blocks
- [x] Preparation on 2026-11-11: `mix deps.get` and `gleam build --target erlang` (the worktree had neither `deps` nor Gleam artifacts).
- [x] `mix compile --force --warnings-as-errors` passed in dev; `MIX_ENV=test mix compile --warnings-as-errors` passed.
- [x] Tests written, not yet run: `test/oli/accounts/audited_access_test.exs` (deletion, admin updates with event routing, no-op, protected keys, validation, audit-failure rollback, nesting refusal, role events, lock/unlock idempotence, confirmation, platform-role sync and composition, own profile); author settings (own name event, crafted protected fields change nothing); collaborator controller (pending invitee deletion records `author_deleted`). Existing tests moved off the removed functions: generic-update tests now assert the `:protected` rejection, admin-path uniqueness tests use the audited commands, and fixtures use `Oli.TestHelpers.update_account_fixture/2` and `put_platform_roles_fixture/2`.
- [x] Owner decision on 2026-11-11: `oli_test` needs no backup before `mix test`; `oli_dev` is backed up with `pg_dump -Fc` under `~/db_backups/` only before a migration. `DATABASE_URL` was unset.
- [x] Checkpoint A run: `mix test` over the new suite and every affected file (accounts, auditing, user and author detail views, both settings pages, collaborator, admin, user auth, LTI, launch, delivery, workspaces, remix, automation setup, audit log list, and the moved fixtures): 6 doctests, 1,068 tests, 4 failures. Fixed: the event reference was stale after the catalog change (regenerated `docs/design-docs/audit-log-events.md`); two tests submitted fields the real forms never send (`independent_learner` in the user detail form, now rejected as protected, and the author's `current_password` virtual field in a generic update); the authors list paging test passed on `--failed` rerun and is the known order-dependent list test. Rerun of the full set: 6 doctests, 1,068 tests, 0 failures, 39 excluded; three unused test aliases removed afterwards and their files rerun (84 tests, 0 failures). ExUnit output has no warnings; the seeds deprecation warning prints before ExUnit starts.
- [x] `mix format --check-formatted` over the changed and new Elixir files and `git diff --check` passed.

## Work-Item Sync
- `handoff.md` is untracked by policy and must not be committed without explicit approval.
- Migrations against `oli_dev` need owner approval and a prior `pg_dump -Fc` backup under `~/db_backups/`; `oli_test` resets need neither.

## Review Loop
- Checkpoint A: pending owner review. `harness-review` runs at checkpoint F over the whole PR, as planned.
