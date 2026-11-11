# PR-03 Coverage: Identity and Platform Administration - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- FDD: `docs/exec-plans/current/features/audit-log-expansion/fdd.md`
- Plan: `docs/exec-plans/current/features/audit-log-expansion/plan.md` (Phase 3, MER-6113)
- Scope: `docs/exec-plans/current/features/audit-log-expansion/jira-subtasks.md` (PR-03)
- Inventory: `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md` (W05, W06, W07, W23, W24, W25, W26), `docs/exec-plans/current/features/audit-log-expansion/caller-inventory.tsv`
- Predecessors: `docs/exec-plans/current/features/audit-log-expansion/design/pr-01-event-contracts-partitioned-storage.md`, `docs/exec-plans/current/features/audit-log-expansion/design/pr-02-boundary-and-ci-with-audited-user-deletion-pilot.md`, `docs/exec-plans/current/features/audit-log-expansion/phase-2-execution.md`

Status: proposed for owner review on 2026-11-11. Source inspected at `ab1bae4434` (last PR-02 commit). No code, test, migration, or database command has run for this design. Implementation evidence belongs in `phase-3-execution.md`, which starts at checkpoint A after approval.

## 1. Slice Summary

Make every supported identity and platform-administration write an audited command. Each command writes the domain change and its events in one transaction, following the PR-02 pattern: an audited facade coordinates the change and the event, separate from the domain function it calls. Close the generic-update paths that can change protected fields today, and move the ten existing producers this PR owns (`author_deleted`, `author_role_changed`, `account_internal_flag_changed`, and the seven flag and rollout events) off the legacy adapter.

In scope (internal blocks, implemented in this order):

1. **Access administration and author deletion (W05).** Lock/unlock, role, internal flag, section-creation rights, admin profile edits, author deletion (detail view and collaborator-invitation cleanup), and the restriction of `Accounts.update_user/2` and `Accounts.update_author/2` to unprotected fields.
2. **Provisioning, profile, linking, and recovery (W06, part of W07).** Registration, invitation, SSO, LTI, and guest account creation; self-service profile and email changes; link/unlink; password creation/change/reset; confirmation; Scenario account bootstrap under the `playwright_setup` system actor.
3. **Authentication (W07).** One audited session issuance and one revocation per account kind, used by password, SSO/OAuth, and LTI login, by logout, and by the password operations that invalidate sessions.
4. **Organizations, consent, and integrations (W23, W24).** Institutions, pending-registration approval, communities and memberships, publishers, research-consent configuration, LMS registrations/deployments, external tools, and the instructor's section deep-link choice.
5. **AI services, credentials, and feature controls (W25, W26).** Registered models, service and feature configurations, API keys, MCP tokens, scoped feature flags, and rollouts/exemptions.

Out of scope:
- Persisted preferences, cookie-consent sync at login, and individual research-consent opt-out. These belong to PR-06 (W27).
- Project collaborator changes (PR-04, W09). Section, enrollment, and invitation-acceptance events (PR-05, PR-06).
- Section-level roster and grade-passback fields reachable through `Sections.update_section/2`. PR-05 owns the section protected-key map (section 4.4).
- Represented author and instructor attribution in Scenarios after bootstrap (PR-04, PR-05).
- New product behavior and new endpoints.
- Automatic retention, Audit Log UI changes (PR-07), and replay protocols (synchronous commands only; PR-04 establishes async replay).

## 2. Requirements Coverage

These are design mappings, not implementation proof. `requirements.yml` gains no evidence entries until real evidence exists. Code and tests carry no requirement or ticket codes.

| Requirement / criteria | This slice's responsibility and planned proof |
| --- | --- |
| FR-006 / AC-019 | Password, SSO/OAuth (Assent, Cognito), and LTI login go through `issue_*_session_multi`; one login event per issued session token, with `auth_method` and the token row ID as `session_ref`. Tests per channel; marker-secret scans of events and logs |
| FR-006 / AC-020 | Logout and token-invalidating password operations record `*_logged_out` or `session_revoked` with the affected account, the actor (self, admin, or system), and a count or token row ID, never the token |
| FR-006 / AC-021 | Failed credentials, failed or canceled provider callbacks, invalid LTI launches, and repeated callbacks issue no token and write no event. Already-absent tokens on logout write nothing. Token-insert and audit failures roll each other back |
| FR-007 / AC-022 | Creation (every provisioning channel), deletion, profile, lock/unlock, role, internal flag, permission flags, and section-creation rights through `Accounts.Audited`; generic updates reject protected fields |
| FR-007 / AC-023 | Link/unlink, recovery request, credential recovery, and confirmation events; secret fields only as redaction markers; actor distinct from the affected account when an admin or system acts |
| FR-007 / AC-024 | `author_deleted` keeps ID, name, and email in the snapshot for both the detail-view and collaborator-cleanup callers |
| FR-025 / AC-060 | Institution, community and membership, publisher, and research-consent commands with typed entities, scope, and safe before/after |
| FR-025 / AC-061 | Registration, deployment, external-tool, and deep-link commands, plus the decline of a pending LMS registration request; `custom_params`, deep-link `custom`, PEM keys, and launch payloads never recorded |
| FR-025 / AC-062 | No supported configuration writer exists for roster or grade passback (section 4.4). LTI launch sync stays routine and unaudited. PR-05 routes the section fields when it closes `update_section/2` |
| FR-026 / AC-063 | `GenAI.Audited` commands for models, service configs, and feature configs; API keys only as redaction markers |
| FR-026 / AC-064 | API key and MCP token lifecycle (`created`, `rotated`, `enabled`, `disabled`, `revoked`) with credential row IDs, owner, and project scope; no value, hash, or MCP hint |
| FR-026 / AC-065 | Flags and rollouts captured in the domain transaction; no-op writes no longer emit events; cache invalidation and PubSub stay after commit |
| FR-029 / AC-069, AC-070 | This PR's part: `author_deleted`, `author_role_changed`, `account_internal_flag_changed`, and the seven flag and rollout events keep their names and gain in-transaction atomicity. Existing audit integration tests are adapted, not deleted. The adapter keeps only the five PR-04 to PR-06 events |
| FR-030 / AC-072 to AC-074 | Marker secrets for passwords, reset/confirm/session tokens, API keys, MCP tokens, AI keys, custom params, and PEM values; scans of events, search text, safe logs, and job arguments |
| FR-035 / AC-092 | Commands add no permission checks. Checks that live inside migrated domain functions (MCP project access) move into the command. Existing route plugs and LiveView guards stay |
| FR-036 | Each new facade is an independent Boundary with private `Mutations`, added to the legacy `deps`, as decided in PR-02 |
| FR-037 / AC-096 | Scenario directives that create accounts, institutions, communities, or feature configs call the audited commands with `Context.for_system(:playwright_setup, source: :scenario)` |
| FR-039 | Login-path latency and query counts (LTI launch, password login) and bulk membership measured at checkpoint F |

### 2.1 Caller and write inventory

Gathered at `ab1bae4434` by following each function's callers, changesets, direct `Repo` writes, and route pipelines. Line numbers are indicative. Every checkpoint re-verifies its rows against the actual diff and records the final mapping in `phase-3-execution.md`. Classification: **M** = migrated to an audited command; **C** = composed inside another audited command; **X** = excluded, with the reason.

#### Access administration and author deletion

| Current path | Today | Class |
| --- | --- | --- |
| `Accounts.delete_author/1` (`lib/oli/accounts.ex:672`) via `author_detail_view.ex:435` | Plain delete; `log_admin_action` after commit, result ignored | M: `Accounts.Audited.delete_author/2`; remove `delete_author/1` and the manual capture |
| `collaborator_controller.ex:151` invitation cleanup | Deletes a pending invitee (no password) inside an open Multi; no audit | C: `delete_author_multi/4` in the controller's Multi |
| `Accounts.admin_update_author/3` (`accounts.ex:1923`) via `author_detail_view.ex:481` | Transaction with `FOR UPDATE`; `author_role_changed` logged inside; `account_internal_flag_changed` captured outside afterwards | M: `admin_update_author/3` in the facade; both events and `account_updated` from one transaction |
| `user_detail_view.ex:503` submit via `Accounts.update_user/2` | Only `is_internal` audited, after commit | M: `admin_update_user/3`, casting only the form's fields (given/family name, email, `can_create_sections`, `is_internal`) |
| `lock_user/1`, `unlock_user/1`, `lock_author/1`, `unlock_author/1` (`accounts.ex:1579`, `:1588`, `:2202`, `:2211`) | Plain update; no audit | M: `lock_account/3`, `unlock_account/3` |
| `admin_confirm_user/1`, `admin_confirm_author/1` | Plain update | M: `admin_confirm_email/2` (`account_updated`, `email_confirmed_at`) |
| `update_user_platform_roles/2` (`accounts.ex:430`) via LTI launch (`lti_controller.ex:284`), open-and-free enroll (`delivery_controller.ex:181`), join (`launch_controller.ex:52`) | Provider- or enrollment-derived role sync | M: `sync_platform_roles_multi/4`; an event only when the set changes (section 4.1) |

#### Provisioning, profile, linking, and recovery

| Current path | Today | Class |
| --- | --- | --- |
| `register_independent_user/1`, `register_author/1` via registration LiveViews | Plain insert | M: `register_account/3`; actor is the new account |
| `create_guest_user/1` via `launch_controller.ex:100`, `delivery_controller.ex:233`, Scenario `hooks.ex:125` | Plain insert | M: `create_guest/2`; actor is the new guest (system actor from Scenarios) |
| `insert_or_update_lms_user/2` inside the LTI launch transaction | Insert or claim sync | C: `provision_lms_user_multi/4`; `provider_provisioning` actor; sync events only when fields change |
| `setup_sso_user/2`, `setup_sso_author/2` (Cognito) | Multi: user, community membership, author, link | M: one command composing account, membership (section 4.4), and link events |
| Assent `create_user_with_identity`, `update_user_details` (`user_assent_auth.ex:80-91`, `author_assent_auth.ex:80-91`) | Direct `Repo` writes | M: `provision_identity_account/3`, `sync_identity_details/3` |
| `bulk_create_invited_users/2`, `create_invited_author/1` (`invite_controller.ex:123`, `:271`; `collaborators.ex:167`) | `insert_all` inside a Multi; plain insert | M: `invite_accounts_multi/4` (one event per created account); inviter as actor |
| `accept_*_invitation*` (six functions, `accounts.ex:1131`-`1751`) | Account update plus enrollment or author_project | C: account part via `accept_invitation_multi/4` (`account_updated`); the enrollment or collaborator part stays with PR-04/06 |
| `author_settings_live.ex:235`, `user_settings_live.ex:383` via `update_author/2`, `update_user/2` | Names submitted through the generic update | M: `update_own_profile/3`, names only |
| `update_user_email/2`, `update_author_email/2` | Token-verified Multi | M: `confirm_email_change/3` |
| `link_user_author_account/2`, `unlink_user_author_account/1` (`link_account_live.ex:39`, `:62`; `author_auth.ex:457`; SSO Multi) | `update_user(author_id)` | M/C: `link_accounts/3`, `link_accounts_multi/4`, `unlink_accounts/2` (`account_linked`) |
| Assent `add_identity_provider/2`, `delete_identity_providers/2` (connecting or disconnecting Google or GitHub from the settings pages, and SSO invitation acceptance) | Direct insert and delete | M: `link_identity/3`, `unlink_identities/3` (`account_identity_linked`, `account_identity_unlinked`, provider name only) |
| `update_*_password/3`, `create_*_password/2`, `reset_*_password/2` (six functions) | Multi: password and delete all tokens | M: `change_password/4`, `create_password/3`, `reset_password/3`; `account_updated` or `account_credential_recovered` plus `session_revoked` |
| `deliver_*_reset_password_instructions/2`, `generate_*_reset_password_token/1` (self-service and admin) | Token insert, then email | M: `request_recovery/3` (`account_recovery_requested`) |
| `deliver_*_confirmation_instructions/2`, `confirm_user/1`, `confirm_author/1` | Token insert; verify Multi | M: `request_recovery/3` (`recovery_kind: confirmation`), `confirm_email/2` |
| `Scenarios.Directives.UserHandler` (`user_handler.ex:93`, `:133`), `Scenarios.Engine.create_default_author/…` (`engine.ex:281`), `bulk_create_enroll_users.ex:94` | Direct changeset inserts and `insert_all` | M: facade with the `playwright_setup` actor and `:scenario` source |
| `Sections.create_hidden_instructor` (`sections.ex:140`) | Inserts a hidden technical account for previews | X: system-managed technical account, never a person |
| `AutomationSetup` setup and teardown (`automation_setup.ex:314`-`486`) | E2E fixture accounts behind the automation API key | X: same technical-fixture classification as PR-02 section 4.5; setup inserts its accounts directly instead of through registration |
| Seeders (`utils/db_seeder.ex`, `utils/seeder/*`), `instructor_dashboard.seed`, `gen_ai.setup_local_codex` | Direct writes | X: development bootstrap tooling, not supported product channels |
| `research_opt_out` (`delivery_controller.ex:96`, `sections.ex:174`), `set_*_preference`, preference writes in authoring LiveViews | Preference writes | X here: PR-06 (W27). They keep using the restricted `update_user/2` and `update_author/2` |
| `extrinsic_state.ex:100`, `:145` (`state`) | Derived learner state | X: derived state; stays on the restricted `update_user/2` |

#### Authentication

| Current path | Class |
| --- | --- |
| `UserAuth.log_in_user/3`, `AuthorAuth.log_in_author/3` (password login, registration auto-login, password-updated re-login, invitation acceptance, link-account form) | M: the token comes from `issue_*_session` with `:password` |
| `UserAuth.create_session/2`, `AuthorAuth.create_session/2` from Assent and Cognito callbacks | M: `create_session/3` with `:sso` or `:cognito` |
| LTI `issue_launch_session` inside the launch transaction (`lti_controller.ex:177-219`) and `SecureAssessments.issue_session/…` (`secure_assessments.ex:94`), installed by `UserAuth.install_session/3` | C: `issue_user_session_multi/4` with `:lti`, composed in the launch transaction |
| `UserAuth.clear_all_session_data/1` from both logouts and `secure_assessment_controller.ex:12`; `AuthorAuth.log_out_author/2` | M: `revoke_session/3` |
| `UserAuth.create_session/2` from guest auto-enroll, open-and-free enrollment, and the compile-gated Playwright route; `Sections.fetch_hidden_instructor/…` sessions for previews (`user_auth.ex:452`, `products_controller.ex:198`) and their exit | X: the session is created for an account the system just created or selected in the same request, without authenticating anyone. These callers keep the existing `create_session/2` and token generation |
| `check_account_lock`, `require_confirmed_email` | X: clear only the browser session; the token row survives, so nothing is revoked or claimed |
| Token cascades from deleting a user, author, section, or resource | X: derived from the audited deletion (or a PR-05 lifecycle event) |

#### Organizations, consent, and integrations

| Current path | Class |
| --- | --- |
| `Institutions.create_institution/1`, `update_institution/2` (controller, `research_consent_view.ex:93`, Scenario handler), soft delete via `status: :deleted` | M: `Institutions.Audited` |
| `approve_pending_registration/1,2`, `approve_pending_registration_as_new_institution/1` | M: one transaction, with events for the created or reused institution, registration, and deployment |
| `delete_pending_registration/1` from the admin decline (`index_live.ex:610`) | M: `Institutions.Audited.decline_pending_registration/2`, `lms_registration_declined` with the declining admin as actor |
| `create_pending_registration/1` (public `/lti/register`), `update_pending_registration/2` (edits before approval, `index_live.ex:519`) | X: an external request and its review before it becomes configuration; the approval records the final values |
| `create/update/delete_registration`, `create/update/delete_deployment` (registration and deployment controllers) | M: `lms_settings_changed` |
| Groups: `create/update/delete_community`, `create_community_account*` (four functions), `delete_community_account/1`, community visibility and institution functions | M: `Groups.Audited`; membership and associations as `community_settings_changed` with `members` changes |
| `find_or_create_community_user_account/2` in the SSO login Multi | C: membership created by `provider_provisioning`, only on insert |
| Inventories: `create/update/delete_publisher`, `set_default_publisher/1` | M: `Inventories.Audited` |
| `Delivery.update_system_research_consent_form_setting/1` (`features_live.ex:510`) | M: `research_consent_settings_changed`, global scope |
| `PlatformExternalTools.register_lti_external_tool_activity/1`, `update_lti_external_tool_activity/2`, `update_lti_external_tool_activity_deployment/2`, `soft_delete_activity_deployment_and_platform_instance/1` | M: `Lti.Audited`, `external_tool_settings_changed` |
| `upsert_section_resource_deep_link/1` via `SectionDeepLinkLaunch.persist_return/4` (`lti_controller.ex:1080`) | C: `external_tool_settings_changed`, section scope, the instructor as actor, inside the existing locked transaction |
| `initialize_section_deep_links`, `copy_section_deep_links`, `initialize_remixed_deep_links` | X: derived copies made by section creation, updates, copying, and remix, which PR-05 owns |
| Unused functions (`create/update/delete_section_resource_deep_link`, `delete_lti_external_tool_activity_deployment`, `PlatformInstances.*`) | Remove from the public API if still unused after migration; otherwise migrate |
| `ValidateIdToken.persist_keys` → `insert_bulk_jwks/1` | X: automatic key caching at login, not configuration |

#### AI services, credentials, and feature controls

| Current path | Class |
| --- | --- |
| `GenAI.create/update/delete_registered_model`, `*_service_config`, `*_feature_config` (three admin LiveViews) | M: `GenAI.Audited`. The LiveViews gain `on_mount {OliWeb.AuthorAuth, :ensure_authenticated}` so an actor exists |
| Scenario `section_handler.ex:210` `create_feature_config` | M: `playwright_setup` actor |
| `Interop.create_key/2`, `update_key/2` (`api_keys_live.ex:204`, `:216`, `:223`, `:241`) | M: `Interop.Audited` |
| `MCP.Auth.create_token/3`, `regenerate_token/3`, `update_token_status/2`, `delete_token/1` | M: `MCP.Audited`; the project access check moves inside the transaction |
| `MCP.Auth.validate_token/1` (`last_used_at`), `track_usage/3` | X: usage bookkeeping |
| `ScopedFeatureFlags.enable_feature/3`, `disable_feature/3`, `remove_feature/3`, `set_features_atomically/3` (toggle component in three views) | M: `ScopedFeatureFlags.Audited`; remove the post-commit capture helper |
| `Rollouts.upsert_rollout/6`, `delete_rollout/5`, `upsert_exemption/5`, `delete_exemption/4` (`canary_rollouts_live.ex`) | M: same facade; remove `capture_audit/4` |
| `Features.change_state` (system feature switches in `features_live.ex:435`) | X: global system features are outside the existing scoped-flag events; the catalog has no event for them |

## 3. Responsibilities & Boundaries

### 3.1 Facades and Boundary topology

Each audited domain gets its own facade with a private `Mutations` module, configured like `Oli.Accounts.Audited`:

| Facade | Covers |
| --- | --- |
| `Oli.Accounts.Audited` (extended) | Accounts, sessions, recovery |
| `Oli.Institutions.Audited` | Institutions, pending-registration approval, registrations, deployments, research-consent configuration |
| `Oli.Groups.Audited` | Communities, memberships, visibility, institution associations |
| `Oli.Inventories.Audited` | Publishers |
| `Oli.Lti.Audited` | External tools and section deep links |
| `Oli.GenAI.Audited` | Models, service configurations, feature configurations |
| `Oli.Interop.Audited` | API keys |
| `Oli.MCP.Audited` | MCP tokens |
| `Oli.ScopedFeatureFlags.Audited` | Flags, rollouts, exemptions |

Each facade declares:

```elixir
use Boundary, top_level?: true, exports: [], check: [out: false]
```

The organization, integration, AI, and credential facades write plain changesets, so instead of a private `Mutations` module each one uses the shared `Oli.Auditing.Command` steps (row lock by primary key, before and after state, change records under the event's field policy, foreign-key failures as `:delete_failed`) and describes its events. `Oli.ScopedFeatureFlags.Audited` keeps a private `Mutations` module, because flag, rollout, and exemption writes have their own lookups, locks, and inserts. The domain contexts lose their raw writers: `Institutions`, `Inventories`, and `PlatformExternalTools` no longer expose them, and `Groups` keeps its email and name helpers but takes the context and writes through the facade.

The legacy boundaries (`Oli`, `OliWeb`, `Oli.Constellation`, `LiveComponentTests`) add each facade to `deps`. No `Mutations` module is exported, and no outgoing check is disabled on a legacy boundary. Research-consent configuration lives in `Institutions.Audited` because it is organization and consent configuration, even though its schema is `Oli.Delivery.ResearchConsent`.

At checkpoint A, verify the topology once with a temporary forbidden reference per new facade. The pattern is the PR-02 fixtures recoverable from `8fc4be1a9c`, run as a manual check and not committed. Record the results in the execution record.

### 3.2 Responsibilities

- **Facade:** owns the transaction, row locks, the before-state read, event construction, and safe errors. Adds no authorization. Moves into the transaction any check that already lived in the migrated domain function.
- **Mutations:** raw writes with the existing changesets and constraints. No auditing, no transaction ownership.
- **Domain context (`Oli.Accounts` and the others):** keeps reads and unprotected writes. A migrated operation leaves no public raw shortcut.
- **Transport (controllers, LiveViews, plugs):** builds the `Context` from the authenticated struct, calls the facade, and runs cookies, redirects, broadcasts, cache invalidation, emails, and Slack messages after commit.

### 3.3 Protected-key ownership map

`Accounts.update_user/2` and `update_author/2` stay public for unprotected fields only.

| Account kind | Unprotected fields (generic update allowed) | Everything else |
| --- | --- | --- |
| User | `state`, `research_opt_out`, `preferences` | Protected: only the facade writes it |
| Author | `preferences` | Protected: only the facade writes it |

A new `User.unprotected_changeset/2` (and the author equivalent) casts only those fields. It adds a `:protected` error when attrs contain any key that `noauth_changeset/2` casts outside the allowlist, so a caller that still passes a protected field fails visibly instead of silently dropping it.

`research_opt_out` and `preferences` stay unprotected until PR-06 audits them. That transition is recorded in `plan.md` phase 6 and is not a protected-field shortcut. `noauth_changeset/2` and the other casting changesets (`external_user_changeset`, `verification_changeset`, `user_identity_changeset`, `details_changeset`, `registration_changeset`, `lock_account_changeset`) are used only from `Mutations`, schema fixtures, and factories.

Within the facade, persisted account fields map to events as follows. A single command emits one event per family that has changes, all sharing the command's operation ID:

| Fields | Event |
| --- | --- |
| `system_role_id` | `author_role_changed` (existing) |
| `is_internal` | `account_internal_flag_changed` (existing) |
| `can_create_sections` | `account_creation_rights_changed` |
| `independent_learner`, `hidden`, `guest`, `platform_roles` (new pseudo key) | `account_permissions_changed` |
| `locked_at` | `account_locked` / `account_unlocked` |
| `author_id` | `account_linked` |
| Every other policy field, including `password` as a marker | `account_updated` |

## 4. Interfaces & Signatures

Every command follows the PR-02 shape: a `*_multi/4` builder whose result goes under `name` and whose internal steps use `{name, step}`, plus a convenience wrapper that owns the transaction and returns `{:error, :nested_transaction}` inside one.

Callers that already run inside a function-style `Repo.transaction/1` (the LTI launch, the collaborator controller, SSO setup) pass the builder to `Repo.transaction/1`. Ecto runs it inside the outer transaction, and a failure rolls back the whole outer transaction; checkpoint B verifies that behavior with a test.

Common error type:

```elixir
@type command_error ::
        :invalid_request
        | :not_found
        | :nested_transaction
        | :protected
        | Ecto.Changeset.t()
        | Oli.Auditing.Error.t()
```

Domain validation failures return the domain changeset where callers render it, as they do today. Logs carry only error keys, never values.

### 4.1 Accounts: access and administration

```elixir
@spec delete_author(Context.t(), pos_integer()) :: {:ok, %{author_id: pos_integer()}} | {:error, command_error()}
@spec delete_author_multi(Multi.t(), Multi.name(), Context.t(), pos_integer()) :: Multi.t()

@spec admin_update_user(Context.t(), pos_integer(), map()) :: {:ok, %User{}} | {:error, command_error()}
@spec admin_update_author(Context.t(), pos_integer(), map()) :: {:ok, %Author{}} | {:error, command_error()}
@spec lock_account(Context.t(), :user | :author, pos_integer()) :: {:ok, struct()} | {:error, command_error()}
@spec unlock_account(Context.t(), :user | :author, pos_integer()) :: {:ok, struct()} | {:error, command_error()}
@spec admin_confirm_email(Context.t(), {:user | :author, pos_integer()}) :: {:ok, struct()} | {:error, command_error()}
@spec sync_platform_roles_multi(Multi.t(), Multi.name(), Context.t(), {pos_integer(), [role]}) :: Multi.t()
```

- Every command locks the target row (`FOR NO KEY UPDATE` for updates, `FOR UPDATE` for deletes), reads the before-state from it, applies the existing changeset, and diffs it with `Changes.diff/3` under the event's field policy.
- Only system administrators change an author's role or the internal flag. The facade does not authorize, so this rule stays with the caller: the author detail view drops `system_role_id` and `is_internal` from the submission of any other admin, as it already did for `is_internal` (the role part lived in `Accounts.admin_update_author/3`). The facade keeps the role inclusion validation.
- `admin_update_user/3` casts only the fields the form shows. Other keys return `:protected`.
- Lock on an already-locked account is a no-op: no event, `{:ok, account}`.
- `delete_author*` mirrors `delete_user*`: `FOR UPDATE`, delete, `author_deleted` with `email`, `name`, and `deleted_by` details, event key `account:primary:deleted`, and foreign-key failures as `:delete_failed` with key-only logs.
- The collaborator controller adds `delete_author_multi` to its Multi only for pending invitees, as today. Its actor is the authenticated project author. The `remove_collaborator` step stays unaudited until PR-04 audits collaborator changes.

### 4.2 Accounts: provisioning, profile, linking, recovery

```elixir
@spec register_account(Context.t() | :self, :user | :author, map()) :: {:ok, struct()} | {:error, command_error()}
@spec create_guest(Context.t() | :self, map()) :: {:ok, %User{}} | {:error, command_error()}
@spec invite_author(Context.t(), String.t()) :: {:ok, %Author{}} | {:error, command_error()}
@spec invite_users_multi(Multi.t(), Multi.name(), Context.t(), [String.t()]) :: Multi.t()
@spec bulk_create_users(Context.t(), [map()], String.t()) :: {:ok, non_neg_integer()} | {:error, command_error()}
@spec accept_invitation_multi(Multi.t(), Multi.name(), {:user | :author, struct(), map(), :password | :sso}) :: Multi.t()
@spec provision_account_multi(Multi.t(), Multi.name(), Context.t(), {:user | :author, pos_integer() | nil, changeset_or_fun, String.t()}) :: Multi.t()
@spec provision_account(Context.t(), {:user | :author, pos_integer() | nil, changeset_or_fun, String.t()}) :: {:ok, struct()} | {:error, command_error()}
@spec update_own_profile(Context.t(), struct(), map()) :: {:ok, struct()} | {:error, command_error()}
@spec confirm_email_change(Context.t(), struct(), String.t()) :: :ok | :error
@spec link_accounts(Context.t(), pos_integer(), pos_integer()) :: {:ok, %User{}} | {:error, command_error()}
@spec link_accounts_multi(Multi.t(), Multi.name(), Context.t(), {pos_integer(), pos_integer() | nil}) :: Multi.t()
@spec unlink_accounts(Context.t(), pos_integer()) :: {:ok, %User{}} | {:error, command_error()}
@spec link_identity(Context.t(), struct(), map()) :: {:ok, struct()} | {:error, command_error()}
@spec unlink_identities(Context.t(), struct(), [struct()]) :: {:ok, {non_neg_integer(), nil}} | {:error, command_error()}
@spec change_password(Context.t(), struct(), String.t(), map()) :: {:ok, struct()} | {:error, command_error()}
@spec create_password(Context.t(), struct(), map()) :: {:ok, struct()} | {:error, command_error()}
@spec reset_password(Context.t(), struct(), map()) :: {:ok, struct()} | {:error, command_error()}
@spec request_recovery(Context.t(), {:user | :author, struct()}, :password_reset | :confirmation | :admin_reset_link) ::
        {:ok, encoded_token :: String.t()} | {:error, command_error()}
@spec confirm_email(:user | :author, String.t()) :: {:ok, struct()} | :error
```

Every command takes a context. For token-verified actions (reset, email change) the caller passes the account the token belongs to, and the command rejects any other actor. `confirm_email/2` is the exception: the token identifies the account, so the command builds the context from it.

`Accounts.register_independent_user/1`, `register_author/1`, `create_guest_user/1`, and the six `accept_*_invitation*` functions keep their signatures and delegate the account part to the facade, so their callers do not change. `Accounts.deliver_*_confirmation_instructions/3` and `deliver_*_reset_password_instructions/3` take the context first, issue the link through `request_recovery/3`, and send the email after commit. LTI (`insert_or_update_lms_user/2`), Cognito (`setup_sso_user/2`, `setup_sso_author/2`), and Assent (`create_user_with_identity/2`, `update_user_details/2`) compose `provision_account_multi/4` into the caller's transaction when there is one. Scenario handlers use `provision_account/2` and `bulk_create_users/3` with `creation_source` `scenario`.

`update_own_profile/3` casts only `name`, `given_name`, and `family_name` (the author settings form submits its read-only `name`); any other field of the account returns `:protected` and changes nothing.

Actor rules:

| Situation | Actor | `creation_source` / notes |
| --- | --- | --- |
| Self-registration and guest creation | The new account. The context is built inside the Multi after insert, so no human actor is invented | `self_registration`, `guest` |
| Invitation (bulk users, author or collaborator invite) | The authenticated inviter | `invitation` |
| LTI, Assent SSO, Cognito provisioning, LTI and SSO claim sync, SSO community membership | `Context.for_system(:provider_provisioning)` | `lti`, `sso`; sync writes an event only when fields change |
| Scenario bootstrap | `Context.for_system(:playwright_setup, source: :scenario)` | `scenario` |
| Token-verified actions (reset, confirm, email change, invitation acceptance) | The verified affected account | The token proves control of the email |
| Self-service forgot password or resend confirmation (unauthenticated) | New system actor `:unauthenticated_request` (section 4.6) | Written only when the account exists; the response stays identical either way |
| Admin reset link, admin reset email, admin confirmation resend | The admin | Distinct from the affected account |

Recovery and credential rules:

- `account_recovery_requested` records `recovery_kind` only. It never records the token, its hash, or the link.
- `reset_password/3` emits `account_credential_recovered` with the password marker, plus `session_revoked` with the `revoked_count` of session tokens it deleted, when that count is greater than zero.
- `change_password/4` emits `account_updated` (password marker) plus `session_revoked`. The settings page's re-login then emits a normal login event. That sequence is the truth and is documented, not merged.
- A reused or expired token fails at lookup and writes nothing.
- The token deletion keeps its existing `:all` contexts.

`request_recovery/3` returns the encoded token to the transport, which sends the email after commit. If email delivery fails after commit, the event still truthfully says the request was recorded and a link issued; it never claims delivery.

### 4.3 Accounts: sessions

```elixir
@type auth_method :: :password | :sso | :cognito | :lti

@spec issue_session_multi(Multi.t(), Multi.name(), Context.t(), {struct(), auth_method(), keyword()}) :: Multi.t()
@spec issue_session(Context.t(), struct(), auth_method(), keyword()) :: {:ok, %{token: binary(), token_id: pos_integer()}} | {:error, command_error()}
@spec revoke_session(:user | :author, binary()) :: {:ok, :revoked | :absent | :revoked_unaudited}
```

The session event:

| Attribute | Value |
| --- | --- |
| Event | `user_logged_in` or `author_logged_in` |
| Subject / affected / actor | The account; the context must belong to it |
| Details | `auth_method`, plus `session_ref` = the token row's integer ID |
| Scope | `section_id` for a secure assessment session |
| Event key | `session:<token_id>:issued` |

Revocation:

- `revoke_session/2` deletes the token row and returns its ID and owner in the same statement.
- Zero rows means `:absent`: no event, and the caller still clears the cookie, as today.
- One row emits `user_logged_out` or `author_logged_out` (event key `session:<token_id>:revoked`) with the owner as actor. Every current caller is the account signing itself out; there is no administrator revocation of a single session to audit.
- Sessions of guests and hidden preview instructors are deleted without an event, because their issuance is not an authentication either.
- If the audited revocation fails, the token row is still deleted directly, the failure is logged with its kind and reason only, and the result is `{:ok, :revoked_unaudited}`. Signing out never leaves a usable session behind.
- `UserAuth` and `AuthorAuth` then broadcast the disconnect and clear the cookie after commit, with the existing topic.

Channel mapping:

- `log_in_user/3` and `log_in_author/3` call the issuing command with `:password`, then install the returned token in the session exactly as today. Registration auto-login, the password-updated re-login, invitation acceptance, and the link-account form reach these functions after a password check, so they record `:password`.
- `log_in_author/3` keeps linking a signed-in user after the session is issued, now through `link_accounts/3`.
- `log_in_user/3`'s cookie-consent sync stays after the issuance, unchanged and unaudited (PR-06).
- Assent and Cognito callbacks, and SSO invitation acceptance, call `UserAuth.create_session/3` or `AuthorAuth.create_session/3` with `:sso` or `:cognito`. `AuthorAuth.create_session/2` is removed because all its callers authenticate; `UserAuth.create_session/2` stays for the excluded callers. The template preview, which used `log_in_user/3`, now uses `create_session/2`, because a hidden preview instructor does not authenticate. `create_session/3` returns `{:ok, conn}` or `{:error, :session_not_issued}`; on failure each caller sends the person back to the login page with a generic error, and password logins keep the existing failure redirect (including the author link-account flow). Cognito's two sessions (user and author) produce two events, because two sessions are issued.
- Assent's existing session issuance when email confirmation is still pending stays unchanged. The event records what the server did.
- The LTI launch replaces `generate_user_session_token` with `issue_session_multi(..., {user, :lti, []})` inside its existing transaction, and `SecureAssessments.issue_session/2` composes it with `scope:` inside its admission transaction. `scope_opts` carries the secure section/resource IDs, which become the event's `section_id` scope. `install_session/3` keeps reading the committed token.
- The excluded callers in section 2.1 keep `create_session/2` and the existing token generation unchanged.
- Failed credentials, provider errors, invalid launches, and canceled callbacks never reach the command, so they produce neither a token nor an event. A repeated provider callback that authenticates again issues a genuinely new session and a new event; there is no replay of the earlier one.

### 4.4 Organizations, consent, and integrations

```elixir
# Institutions.Audited
create_institution/2, update_institution/3, delete_institution/2   # delete = existing soft delete
approve_pending_registration/3                                       # (context, pending_id, opts)
decline_pending_registration/2                                       # (context, pending_id)
create_registration/2, update_registration/3, delete_registration/2
create_deployment/2, update_deployment/3, delete_deployment/2
update_system_research_consent/2

# Groups.Audited
create_community/2, update_community/3, delete_community/2
add_community_members/3          # one event per created membership, per-target transactions (see below)
remove_community_member/2
add_community_visibility/2, remove_community_visibility/2
add_community_institutions/3, remove_community_institution/2
community_membership_multi/4     # SSO provisioning composition

# Inventories.Audited
create_publisher/2, update_publisher/3, delete_publisher/2, set_default_publisher/2

# Lti.Audited
register_external_tool/2, update_external_tool/3, update_external_tool_deployment/3, delete_external_tool/2
persist_deep_link_multi/4        # composed inside SectionDeepLinkLaunch.persist_return/4
```

Each command locks the target row (or the parent for associations), reads the before-state, writes, and emits one `*_settings_changed` event per semantic entity: institution, community, publisher, research-consent form, registration, deployment, external tool, or section resource deep link.

- Creation and deletion produce one-sided changes.
- No-ops write no event.
- Associations record `members` as `added` or `removed` with the related type and ID, and the related entity as a `:scope` ref.

| Entity | Scope | Event |
| --- | --- | --- |
| Institution | `institution_id` | `institution_settings_changed` |
| Community / membership / association | Community as entity; ref to the member or institution | `community_settings_changed` |
| Publisher | Publisher; `set_default_publisher` emits one event for the old default and one for the new, same operation | `publisher_settings_changed` |
| System research-consent form | Global scope ref | `research_consent_settings_changed` |
| Registration | Global scope ref (registrations have no institution column) | `lms_settings_changed` |
| Declined pending registration request | Global scope ref | `lms_registration_declined` |
| Deployment | `institution_id` | `lms_settings_changed` |
| External tool (platform instance, activity registration, deployment) | Global scope ref; one event per tool | `external_tool_settings_changed` |
| Section deep link | `section_id`, resource ref | `external_tool_settings_changed` |

Approval details:

- `approve_pending_registration/3` keeps its single transaction.
- It emits events only for the institution (if it creates one), the registration, and the deployment.
- The pending-row deletion is triage and writes no event.
- Email and Slack notifications stay in the post-commit task.

Decline:

- `decline_pending_registration/2` locks the pending row `FOR UPDATE`, deletes it, and emits `lms_registration_declined` in the same transaction, with the admin from the LiveView's `current_author` as actor.
- The event's entity is the pending registration, with global scope. Its snapshot keeps `name`, `institution_url`, `country_code`, `issuer`, `client_id`, and `deployment_id`, so the declined request stays identifiable after the row is gone. `institution_email` is not recorded: it is contact data and is not needed to identify the request.
- A request already approved or declined returns `:not_found` and writes no event.
- The existing Slack notification stays after commit.

Bulk membership:

- `add_community_members/3` and `add_community_institutions/3` keep today's per-target outcome (some targets can succeed while others fail).
- Each target is one transaction with its own event, and all targets share one operation ID.
- The returned result keeps the existing success/error shape.
- This preserves user-visible behavior while keeping every event truthful (FDD section 7.2).

Roster and grade passback:

- No admin or instructor UI configures `nrps_enabled`, `grade_passback_enabled`, `line_items_service_url`, or `nrps_context_memberships_url` on purpose. The LTI launch syncs them on every launch (routine, unaudited), and section creation and copying derive them.
- `OliWeb.Sections.EditView` passes form params to `Sections.update_section/2`, whose changeset casts those fields. PR-05 owns the section protected-key map and must either reject those keys from the generic path or route them to `roster_settings_changed` and `grade_passback_settings_changed`. This design records that handoff in `plan.md` phase 5 during checkpoint D.
- `sso_settings_changed` and `lti_settings_changed` also have no supported writer: there is no administrable SSO configuration, and tool keys are seeded. They stay in the catalog without a producer, consistent with "a name is admitted only for an existing supported action" (FDD 5.2), and are documented as unused.

### 4.5 AI services, credentials, feature controls

```elixir
# GenAI.Audited  (entity :ai_service, id "registered_model:<id>" | "service_config:<id>" | "feature_config:<id>")
create_registered_model/2, update_registered_model/3, delete_registered_model/2
create_service_config/2, update_service_config/3, delete_service_config/2
create_feature_config/2, update_feature_config/3, delete_feature_config/2   # section_id override → section scope

# Interop.Audited  (entity :api_key)
create_key/3                       # returns {:ok, {key, plaintext}} once, as today
set_key_status/3                   # :enabled | :disabled
update_key_settings/3              # the four flags and registration_namespace; other keys → :protected

# MCP.Audited  (entity :mcp_token, affected :author owner, scope project_id)
create_token/4, regenerate_token/4, set_token_status/3, revoke_token/2

# ScopedFeatureFlags.Audited
enable_feature/3, disable_feature/3, remove_feature/3, set_features_atomically/3
upsert_rollout/…, delete_rollout/…, upsert_exemption/…, delete_exemption/…   # existing arities plus a leading context
```

AI services:
- `api_key` and `secondary_api_key` are recorded only as redaction markers.
- The create flow's placeholder `"dummy"` keys are an insert detail; the change shows only that a key was set.

Credentials:
- `credential_lifecycle_changed` carries a `lifecycle` change (`created`, `rotated`, `enabled`, `disabled`, `revoked`) and, for API keys, the flag and namespace changes.
- An API-key flag update without a status change still uses this event, with only the field changes. Checkpoint E adds a catalog example for it.
- `update_key_settings/3` accepts the fields the API keys page edits: the four flags and `registration_namespace`.
- The API key's admin-entered `hint` may go into details: it is a label, not part of the key. Correct the `ApiKey.hint` exclusion text in `fields.ex`, which calls it a partial key hint.
- The MCP token's `hint` (`mcp_****1234`) is derived from the secret and is never recorded.
- One-time plaintext values pass through the command's return value only. They are never in the event, the context, logs, or job arguments.

MCP tokens:
- `create_token` and `regenerate_token` move the existing `verify_author_project_access` check into the transaction, with `FOR SHARE` on the `AuthorProject` row.
- `regenerate_token` on a missing token falls back to create and emits `created`, as the existing behavior implies. On a disabled token it keeps returning `:token_disabled`.
- `set_token_status/3` replaces `update_token_status/2`; the admin view passes its authenticated author.
- `delete_token/1` has no callers and becomes `revoke_token/2` for completeness, tested but not wired to UI.

Feature flags and rollouts:
- Capture moves into the domain transaction through `Auditing.append/3`. Audit failure now rolls back the change instead of being swallowed. This is the intended FR-003 behavior and the main compatibility change for these callers.
- Event names stay the same.
- The new event key includes the scope (`flag:<feature>:<project_N | section_N>:<event>`). Already-migrated legacy rows keep their old keys.
- Enabling an already-enabled flag or disabling an already-disabled one returns the existing result and writes no event, aligning with the no-op rule.
- A nil actor is no longer accepted. The toggle component already receives a `User` or `Author` from all three mounts; it builds the context with `Context.for_actor`.
- The two-argument compatibility variants and their test are removed with the unaudited path.
- After commit, rollouts keep the existing telemetry, the `Cachex.del`, and the PubSub broadcast. Flags keep their existing absence of cache effects.
- A rollback in the domain transaction returns `{:error, reason}` to callers.

### 4.6 Catalog, field policy, and context changes

All are extensions or tightenings of PR-01 contracts that have no production rows yet. Regenerate `docs/design-docs/audit-log-events.md` and add examples in `test/support/audit/event_examples.ex` in the same checkpoint.

- **`Context`:** add the system actor `:unauthenticated_request` ("Unauthenticated request"). The database check already admits any well-formed key.
- **Login-provider identities:** add `account_identity_linked` and `account_identity_unlinked` to the account family, with only the provider name in details; the provider's account uid is never recorded.
- **System actor in account events:** admit `:system` in `account_updated`, `account_linked`, and `account_creation_rights_changed`, because identity-provider provisioning updates claims, links Cognito accounts, and grants Cognito users section creation.
- **`account` family:** add the `platform_roles` pseudo key (sorted role URIs as a `set` change) to `Fields.user_account/0` and its `schema_sources/0` declaration, and admit the system actor in `account_permissions_changed`, because LTI launches sync roles under `provider_provisioning`.
- **Organizations family:** admit the system actor, because Scenario bootstrap creates institutions and communities under `playwright_setup`.
- **Integrations family:** add `lms_registration_declined` ("LMS registration request declined", entity type `:pending_registration`, a lifecycle event without change fields). Drop the family's `required_one_of: [:institution_id, :section_id]`, which registrations and system-wide tools cannot satisfy: the facades set `institution_id` for deployments and `section_id` for deep links, registrations and tools carry no scope column, and `roster_settings_changed` and `grade_passback_settings_changed` require `section_id`.
- **Organizations family:** add `:research_consent` to the default `entity_types`.
- **`fields.ex` sources:** declare `CommunityAccount`, `CommunityInstitution`, `CommunityVisibility`, `Oli.Delivery.ResearchConsent`, `PendingRegistration` (snapshot fields as in section 4.4; `institution_email` and the endpoint URLs excluded), `LtiSectionResourceDeepLink`, `ActivityRegistration` (title, description, petite label for tools), `SsoJwk`, and the `Lti_1p3` JWK schema (`pem` excluded as a secret, never recorded). The drift test then covers them.
- **`fields.ex` deep links:** declare `LtiSectionResourceDeepLink` with `url`, `title`, and `text` audited, `custom` as a secret, and `type` excluded (its name collides with `Section.type`, which the integration policy also reads).
- **`fields.ex` secrets:** classify `custom_params` and the deep link's `custom` as `:secret` markers, because they are free-form and can carry tool credentials. Leave the `private_key` pseudo key as a never-produced key, with corrected documentation; the change-fields rule forbids removing it.
- **Released names:** no event is renamed or removed. `released_event_names.txt` is unchanged.

The legacy adapter keeps only the five events owned by PR-04 to PR-06 (`project_published`, `google_doc_imported`, `section_created`, `resource_attempt_deleted`, `clickhouse_admin_operation_initiated`). Its moduledoc and `@events` list are updated, and its tests for the ten removed mappings move to the new command tests.

## 5. Data Flow & Edge Cases

Main flow, for every command:

1. The transport authenticates (existing plugs and `on_mount`) and builds `Context.for_actor(current_author | current_user, source: ...)` or a fixed system context.
2. The facade opens or joins a transaction, locks the target or parent row, and reads the before-state.
3. `Mutations` applies the existing changeset or write.
4. The facade diffs before and after under the event's field policy. A no-op stops here and returns the existing result without an event.
5. `Auditing.append/3` writes each event. Any failure rolls back the mutation and every other event.
6. After commit, the transport runs cookies, redirects, broadcasts, cache invalidation, and notifications.

| Situation | Required result |
| --- | --- |
| Domain validation failure | No change, no event; existing changeset rendered |
| Audit build or insert failure, missing partition | Mutation, token, or membership rolled back; safe `Auditing.Error`; caller's existing failure flash |
| Lock already locked, flag already enabled, role unchanged | `{:ok, existing}`, no event |
| Concurrent admin updates of one account | Serialized by the row lock; each emits only its own real diff |
| Logout of a token already deleted | `:absent`, no event, cookie cleared |
| Repeated or concurrent logout of one token | `DELETE ... RETURNING` lets exactly one win; one event |
| Password reset with a reused token | Lookup fails; no change, no event |
| Decline of a pending request already approved or declined | `:not_found`, no event |
| Login with wrong password, failed provider callback, invalid LTI JWT | No token, no event |
| Token commit succeeds, response or cookie delivery fails | The event stands: the server issued the session (FDD 7.3) |
| LTI launch fails after session issuance inside its transaction | Whole launch, token, and login event rolled back |
| Collaborator cleanup fails after `delete_author_multi` | Author deletion and its event rolled back with the outer Multi |
| Generic `update_user/2` or `update_author/2` with a protected key | `{:error, changeset}` with a `:protected` error; nothing written |
| Bulk membership with some invalid emails | Valid targets committed with one event each, invalid ones reported as today, shared operation ID |
| API key settings update with a field outside the edited set | `:protected`; nothing written |
| MCP token created for a project the author no longer collaborates on | Existing access error inside the transaction; no token, no event |
| Rollout PubSub or cache failure after commit | Committed change and event stand; existing log behavior |
| Secret values in params (passwords, API keys, custom params, tokens) | Redaction marker or omitted; never in changes, details, search text, logs, or errors |
| Account renamed or deleted after an event | Event-time snapshots unchanged |
| Same numeric ID for a user and an author | Typed entity and affected columns keep them distinct |

No schema migration is planned. PR-01's tables, indexes, and checks are sufficient.

## 6. Test Plan

The test policy is the one clarified in PR-02. Unrelated fixtures and factories need no audit. Each command gets focused tests of its real mutation-and-event transaction, plus transport tests where a user-visible path changes. Existing suites are adapted, not removed. Concurrency tests use the PR-02 patterns: `Sandbox.unboxed_run`, `pg_backend_pid()`, `pg_blocking_pids`, and scoped cleanup under `SET LOCAL oli.audit_log_allow_mutation = 'on'`. Audit-insert failures use a `pg_temp` trigger with `capture_log`.

- Unit or component tests:
  - Field-to-event routing for accounts (each row of the section 3.3 table) and the `:protected` rejection of the restricted generic updates.
  - Catalog examples and contract tests for every changed or newly produced event, including the integrations scope rules, `lms_registration_declined`, `platform_roles`, and the `unauthenticated_request` actor.
  - Field-policy drift test passing with the newly declared schemas; secret classification for `custom_params`, deep link `custom`, `pem`, AI keys.
  - Marker-secret scans: plant marker values in passwords, reset/confirm tokens, session tokens, API keys, MCP tokens, AI keys, and custom params; assert they are absent from events (changes, details, snapshots, search text) and captured logs.
- Integration tests (per block, at the application boundary and the supported transport):
  - **Access:** each command's success, no-op, invalid context, audit-insert failure rollback, and concurrent update. Author deletion from the detail view and from collaborator cleanup, with event-time identity after deletion and outer-Multi rollback. Role change by an account admin (dropped) versus a system admin (recorded). Removed manual captures leave exactly one event of each kind.
  - **Provisioning and profile:** registration, guest, invitation (bulk and single), LTI first launch and claim sync (event only on change), Assent and Cognito provisioning, link/unlink, email change confirmation, invitation acceptance. The settings pages change only names; a submitted protected key changes nothing.
  - **Recovery:** requests (self, unauthenticated, admin), reset with a valid token, reused and expired tokens, confirmation, and password change producing `account_updated` + `session_revoked` + re-login event.
  - **Sessions:** one event per password, SSO/OAuth, and LTI channel. Wrong credentials, failed callback, invalid launch, and canceled flows emit nothing. Repeated logout, concurrent logout of one token, token-insert failure versus audit failure each rolling back the other, LTI launch failure after issuance, Cognito double session. Excluded session callers emit nothing and keep working.
  - **Organizations and integrations:** each lifecycle transition; approval with new and existing institutions; decline with its event, audit-failure rollback, already-handled request, and no `institution_email` in the event; bulk membership partial success with shared operation ID; set default publisher; system research consent distinct from a user's opt-out (which must emit nothing); deep-link replacement by an instructor within the existing locked transaction; learner refusal and stale-return scenarios in `test/scenarios/lti_external_tool/section_configuration_test.exs` still pass with no event.
  - **Services, credentials, flags:** each lifecycle transition and ownership boundary; API key settings allowlist; one-time plaintext returned but absent from events; MCP project access inside the transaction; flag no-op; rollout cache and PubSub after commit only; audit failure rolls back the flag change; the retained assertions of `test/oli/scoped_feature_flags/audit_integration_test.exs` and `rollouts_test.exs` adapted to the new atomic contract and scoped event keys.
  - **Scenarios:** user, bulk user, default author, institution, community, and feature-config directives create their entities under `playwright_setup`.
  - Regression command from `plan.md` phase 3, plus the new suites, plus `test/oli_web/controllers/cognito_controller_test.exs`, `test/oli_web/controllers/lti_controller_test.exs`, `test/oli_web/common/assent_auth_web_test.exs`, `test/oli_web/controllers/user_session_controller_test.exs`, `test/oli_web/live/api_keys/api_keys_live_test.exs`, `test/oli/auditing/legacy_adapter_test.exs`, and `test/oli_web/live/admin_live_test.exs`.
- Manual checks:
  - Boundary forbidden-reference check per new facade (section 3.1), recorded and not committed.
  - Local browser pass on the admin detail views, login and logout (password and LTI), a rollout change, and the Audit Log list showing the new events, if the owner wants UI evidence.
  - Latency and query counts at checkpoint F: LTI launch and password login with and without the audited issuance, bulk membership of 100 and 1,000 targets. Review threshold `max(10 ms, 20% of baseline p95)`, not an SLA.
  - Full `mix test` at the final gate, because shared test support (Scenario handlers) changes. Clean ExUnit output; known list-test flakiness rerun with `--failed` and recorded.

Database safety: every `mix test` run needs owner approval and a prior `pg_dump -Fc` of `oli_test` under `~/db_backups/`. Verify `DATABASE_URL` is unset and the target is `oli_test` first.

## 7. Risks & Open Questions

- Risks:
  - **TRIAGE-2569:** live navigation can skip role-specific admin plugs. Every command in this PR relies on the existing route plugs and inherits that residual risk; it is not fixed here.
  - **Behavior changes callers will see:** flag and rollout writes fail when audit fails (previously swallowed); enabling an already-enabled flag no longer emits an event; generic account updates reject protected keys. These are intended and tested.
  - **Event volume:** every LTI launch and login writes an event, as the login criteria require. Checkpoint F measures the write overhead on the launch path.
  - **Size:** this is the largest coverage group: nine facades, `user_auth.ex`, `author_auth.ex`, the LTI launch, the admin LiveViews and controllers, Scenario handlers, and their tests. Checkpoints A–F keep review incremental within one PR.
  - **Shared files:** any parallel TRIAGE-2569 fix touches the same admin LiveViews and `router.ex`.
- Owner decisions (2026-11-11):
  - Bulk community membership keeps today's per-target partial success, with one transaction and event per target (section 4.4).
  - Declining a pending LMS registration request is audited; edits before approval are not (section 4.4).

## 8. Definition of Done

### Design gate

- [x] Requirement coverage is explicit (section 2), with deferred and excluded scope distinguished.
- [x] Interfaces are concrete (section 4), including actor rules, event mapping, and composition inside existing transactions.
- [x] Test plan covers main and edge paths (section 6).
- [x] Validation passes (`validate_work_item.py --check design`).
- [x] Owner decisions recorded in section 7.
- [ ] Owner approves the design before checkpoint A.

### Implementation checkpoints after approval

Each checkpoint pauses for owner review, keeps `phase-3-execution.md` current, and is not permission to commit.

1. **A — Access administration and generic-update closure.** New facade functions for deletion, admin updates, lock/unlock, confirmation, platform roles; restricted `update_user/2` and `update_author/2`; detail views, collaborator controller, and settings pages migrated; manual captures removed; Boundary check for new facades.
2. **B — Provisioning, profile, linking, recovery, Scenarios.** Catalog and `Context` changes; registration, guest, invitation, LTI, Assent, Cognito, settings, link, password and recovery commands; Scenario handlers under `playwright_setup`; nested-transaction composition test.
3. **C — Sessions.** Issuance and revocation commands for password, SSO/OAuth, and LTI login and for logout.
4. **D — Organizations, consent, integrations.** Four facades; pending-registration decline; field-policy declarations and secret classification; integrations scope rules; deep-link composition; PR-05 handoff note for roster and grade passback in `plan.md`.
5. **E — AI services, credentials, flags.** Three facades plus the flag facade; GenAI actor `on_mount`; API key settings allowlist; MCP access check inside the transaction; flag and rollout migration; legacy adapter trimmed to the five remaining events.
6. **F — Final verification.** Format, `mix compile --warnings-as-errors` in dev, test, and playwright; affected and full suites; latency evidence; `harness-review` (security, performance, Elixir, UI for the LiveView changes); work-item validation; regenerate the event reference; caller inventory closed against the diff.

No commit, push, PR, Jira change, or change to `handoff.md` is part of this design. PR-03's draft base is `sub-task/MER-6112-boundary-and-ci-with-audited-user-deletion-pilot`, opened with the caution block copied from #7025.
