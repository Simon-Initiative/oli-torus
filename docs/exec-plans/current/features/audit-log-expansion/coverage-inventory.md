# Audit Log Expansion - Coverage and sizing inventory

Evidence date: 2026-10-29. Jira MER-6066 read in full; code at `237980b77c`. This is a planning inventory, not a claim that every dynamic caller has been proved covered. Each slice must close its exact field/function/caller matrix before implementation acceptance. No runtime call graph or production telemetry was collected.

These work areas are research/implementation subdivisions within **seven PRs**, including four coverage PRs. They are not individual PRs or subtasks. Splitting a coverage PR is considered only if its execution demonstrates excessive size and the owner agrees.

## Method and limitations

The source and entry-point anchors below were located/read in the checkout. `caller-inventory.tsv` records lexical matches of the listed representative symbols followed by `(` in `.ex`/`.exs` files under `lib` and `test`, with file-relative line numbers. Definitions, documentation and unrelated same-named functions can match; indirect/dynamic calls, pipelines without parentheses and other names can be missed. Counts are a fan-out triage aid, not actual call counts, exact files to edit or proof of absence. A zero count only means these chosen strings did not match. Directory anchors indicate further owned enumeration, not an unowned residual scope bucket.

Reproduce any symbol with `rg -n 'SYMBOL\s*\(' lib test`, escaping regex punctuation in the symbol. Follow module aliases/imports, pipelines, generic attribute maps and direct `Repo` writes during slice design. The precise symbols and matched lines are preserved in the TSV. All path anchors were checked to exist when this plan was generated.

## Findings that change the split

- User deletion has a focused LiveView caller; author deletion also occurs in `lib/oli_web/controllers/collaborator_controller.ex` during invitation cleanup. Use user deletion for the Boundary pilot and migrate author deletion with access administration.
- `update_user`, `update_author`, `update_project` and `update_section` are shared paths. Closing only named action functions would leave field-level bypasses. The plan requires protected-key dispatch/restriction and mixed-attribute tests for each slice.
- Assessment single-setting updates use transaction composition, while bulk operations and separate history have distinct write paths. Keep settings-history migration with that domain, after storage and Boundary, and exceptions in the next focused slice.
- `Remix.save` already commits hierarchy/materialization/publication/deep-link work together. Audit the persisted save diff, not each transient UI operation or nested helper.
- `lib/oli_web/live/admin/restore_user_progress.ex` contains direct Repo updates. Learner intervention work includes extracting orchestration, not merely adding a call around an existing context function.
- ClickHouse administration uses Task.start and an initiation capture, while terminal outcomes are progress/telemetry messages. Prove Oban plus terminal-event preservation versus pruning inside the first actual async coverage workflow; ClickHouse is handled in PR-06. The checked-in Pruner configuration is not itself a historical-outcome solution.
- `lib/oli_web/controllers/api/trigger_point_controller.ex` invokes runtime triggers; it is an exclusion test anchor, not a configuration writer. Instructor recommendation settings are written by the section component through Sections.update_section. Content/project configuration also needs field-level revision/experiment inspection.
- Project/section/account creation has substantial test/Scenario fan-out. Migrate represented actors in each domain slice; factories for unrelated setup need not simulate a whole audited workflow.

## Internal work areas and PR ownership

### W01: Event contracts, partitioned storage, and central-history cutover

- Owning implementation PR: **PR-01**.
- Actions: All catalog event contracts; existing 16 event formats; historical conversion; partition provisioning and safe rollback.
- Requirements: FR-001, FR-002, FR-029, FR-030, FR-031, FR-032, FR-034, FR-039.
- Domain/storage anchors: `lib/oli/auditing.ex`, `lib/oli/auditing/log_event.ex`, `lib/oli/release.ex`, `priv/repo/migrations`, `config/config.exs`, `config/runtime.exs`.
- Entry-point anchors: `lib/oli_web/live/admin/audit_log_live.ex`, `lib/oli_web/live/admin/audit_log/table_model.ex`, `lib/oli/delivery/section_creation_auditor.ex`.
- Existing test anchors: `test/oli/auditing_test.exs`, `test/oli_web/live/admin/audit_log_live_test.exs`, `test/oli/delivery/section_creation_test.exs`.
- Lexical matching files: 12 lib / 3 test; symbols: `capture`, `capture!`, `get_event!`, `browse_events`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Largest exceptional PR: schema + all contract tests + conversion + recovery. Review in contract, storage, and migration blocks before implementation expands; stop if the rehearsal exceeds the accepted window.

### W02: Boundary pilot with audited user deletion

- Owning implementation PR: **PR-02**.
- Actions: Delete a user through Accounts.Audited, with raw Accounts.Audited.Mutations; compiled forbidden-call fixtures and CI.
- Requirements: FR-003, FR-004, FR-007, FR-029, FR-035, FR-036.
- Domain/storage anchors: `lib/oli/accounts.ex`, `mix.exs`, `.github/workflows/build.yml`.
- Entry-point anchors: `lib/oli_web/live/users/user_detail_view.ex`.
- Existing test anchors: `test/oli/accounts_test.exs`, `test/oli_web/live/users`.
- Lexical matching files: 2 lib / 2 test; symbols: `delete_user`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Boundary topology is still a proposal. The pilot must fail visibly rather than mask legacy dependency problems. User deletion has a narrower production caller set than author deletion.

### W03: Assessment settings and historical consolidation

- Owning implementation PR: **PR-05**.
- Actions: Individual assessment settings, bulk apply, reset/defaults; centralize existing settings_changes history and retire it.
- Requirements: FR-009, FR-033.
- Domain/storage anchors: `lib/oli/delivery/settings/assessment_settings.ex`, `lib/oli/delivery/settings.ex`, `lib/oli/delivery/settings/settings_changes.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/assessment_settings/settings_table.ex`, `lib/oli_web/live/sections/assessment_settings/settings_live.ex`.
- Existing test anchors: `test/oli/delivery/settings_test.exs`, `test/oli/delivery/sections/assessment_settings_test.exs`, `test/scenarios/delivery/assessment_settings/assessment_settings_test.exs`.
- Lexical matching files: 1 lib / 0 test; symbols: `build_settings_changes`, `insert_settings_changes`, `create_settings_change`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Existing bulk implementation and separate history differ from single-setting Multi; source secrets and default semantics increase migration review cost.

### W04: Student exceptions and exemptions

- Owning implementation PR: **PR-05**.
- Actions: Create/update/delete student assessment exceptions and exemptions, including bulk removal.
- Requirements: FR-010.
- Domain/storage anchors: `lib/oli/delivery/settings/student_exceptions.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/assessment_settings/student_exceptions_live.ex`, `lib/oli_web/live/sections/assessment_settings/student_exceptions_table.ex`, `lib/oli/scenarios/directives/student_exception_handler.ex`.
- Existing test anchors: `test/oli/delivery/settings/student_exceptions_test.exs`, `test/scenarios/delivery/assessment_settings/assessment_settings_test.exs`.
- Lexical matching files: 3 lib / 1 test; symbols: `set_exception`, `delete_exceptions`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Exception/default interactions and bulk targets must preserve existing learner eligibility.

### W05: Account access administration and author deletion

- Owning implementation PR: **PR-03**.
- Actions: User/author lock and unlock; roles, permissions, internal flag and section-creation rights; author deletion.
- Requirements: FR-007, FR-029.
- Domain/storage anchors: `lib/oli/accounts.ex`.
- Entry-point anchors: `lib/oli_web/live/users/user_detail_view.ex`, `lib/oli_web/live/users/author_detail_view.ex`, `lib/oli_web/controllers/collaborator_controller.ex`.
- Existing test anchors: `test/oli/accounts_test.exs`, `test/oli/accounts/collaborator_test.exs`, `test/oli_web/controllers/collaborator_controller_test.exs`.
- Lexical matching files: 7 lib / 12 test; symbols: `delete_author`, `admin_update_author`, `lock_user`, `unlock_user`, `lock_author`, `unlock_author`, `update_user_platform_roles`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Generic account updates can bypass dedicated commands; author deletion is nested in collaborator cleanup.

### W06: Account provisioning, profile changes, and linking

- Owning implementation PR: **PR-03**.
- Actions: Create users/authors via registration, invitation and provisioning; profile/email changes; link/unlink accounts; Scenario bootstrap actor.
- Requirements: FR-007, FR-037.
- Domain/storage anchors: `lib/oli/accounts.ex`, `lib/oli/scenarios/runtime_opts.ex`.
- Entry-point anchors: `lib/oli_web/live/user_registration_live.ex`, `lib/oli_web/live/author_registration_live.ex`, `lib/oli_web/live/user_settings_live.ex`, `lib/oli_web/live/author_settings_live.ex`, `lib/oli_web/live/link_account_live.ex`, `lib/oli/scenarios/directives/user_handler.ex`.
- Existing test anchors: `test/oli/accounts_test.exs`, `test/oli/lti_accounts_test.exs`, `test/oli_web/live/user_registration_live_test.exs`, `test/oli/scenarios/demo_accounts_test.exs`.
- Lexical matching files: 14 lib / 13 test; symbols: `register_author`, `register_independent_user`, `update_user`, `update_author`, `link_user_author_account`, `unlink_user_author_account`, `update_user_email`, `update_author_email`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Broad generic write fan-out and new-account actor establishment; provider paths must not lose attribution.

### W07: Authentication, session revocation, and credential recovery

- Owning implementation PR: **PR-03**.
- Actions: Password/SSO/OAuth/LTI user and author login/logout; forced revocation; password creation/change/recovery.
- Requirements: FR-006, FR-007.
- Domain/storage anchors: `lib/oli/accounts.ex`, `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`.
- Entry-point anchors: `lib/oli_web/controllers/user_session_controller.ex`, `lib/oli_web/controllers/author_session_controller.ex`, `lib/oli_web/controllers/lti_controller.ex`, `lib/oli_web/controllers/user_authorization_controller.ex`, `lib/oli_web/controllers/author_authorization_controller.ex`.
- Existing test anchors: `test/oli_web/user_auth_test.exs`, `test/oli_web/author_auth_test.exs`, `test/oli/accounts/secure_session_test.exs`, `test/oli/accounts_test.exs`.
- Lexical matching files: 16 lib / 117 test; symbols: `log_in_user`, `log_in_author`, `create_session`, `install_session`, `log_out_user`, `log_out_author`, `delete_user_session_token`, `delete_author_session_token`, `reset_user_password`, `reset_author_password`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Transport cookies are not part of a database transaction; callback reuse and token invalidation need explicit semantics.

### W08: ClickHouse administrative execution and outcomes

- Owning implementation PR: **PR-06**.
- Actions: ClickHouse setup/migrate-up/migrate-down initiation and confirmed outcomes, using the shared Oban pattern established in coverage work.
- Requirements: FR-005, FR-027, FR-029, FR-039.
- Domain/storage anchors: `lib/oli/clickhouse/admin_operations.ex`, `config/config.exs`, `config/runtime.exs`.
- Entry-point anchors: `lib/oli_web/live/admin/clickhouse_analytics_view.ex`, `lib/oli_web/live/admin/clickhouse_backfill_live.ex`.
- Existing test anchors: `test/oli/clickhouse/admin_operations_test.exs`.
- Lexical matching files: 1 lib / 1 test; symbols: `AdminOperations.start`. Counts are not runtime calls or exact change sizes.
- Implementation risk: External destructive effects and terminal capture versus pruning require explicit recovery evidence; this work is part of PR-06, not a separate pilot.

### W09: Project lifecycle, publishing, ownership, and collaborators

- Owning implementation PR: **PR-04**.
- Actions: Project create/duplicate/delete, publish, owner transfer and collaborator invite/accept/remove; project creation stage of imports.
- Requirements: FR-008, FR-029, FR-037.
- Domain/storage anchors: `lib/oli/authoring/course.ex`, `lib/oli/authoring/collaborators.ex`, `lib/oli/publishing.ex`.
- Entry-point anchors: `lib/oli_web/controllers/project_controller.ex`, `lib/oli_web/controllers/collaborator_controller.ex`, `lib/oli_web/live/projects/projects_live.ex`, `lib/oli/scenarios/directives/project_handler.ex`, `lib/oli/scenarios/directives/publish_handler.ex`.
- Existing test anchors: `test/oli/course_test.exs`, `test/oli/publishing_test.exs`, `test/oli/accounts/collaborator_test.exs`, `test/oli_web/controllers/collaborator_controller_test.exs`.
- Lexical matching files: 22 lib / 72 test; symbols: `create_project`, `create_project_from_source`, `create_project_from_archive`, `publish_project`, `update_author_project`, `add_collaborator`, `remove_collaborator`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Publishing and generic project updates have broad internal use. Separate publication success from content revision bookkeeping.

### W10: Destructive authoring and media operations

- Owning implementation PR: **PR-04**.
- Actions: Remove pages/containers, activities from pages, activity-bank questions, and media; single/bulk deletion and supported restoration.
- Requirements: FR-013.
- Domain/storage anchors: `lib/oli/authoring/editing/resource_editor.ex`, `lib/oli/authoring/editing/container_editor.ex`, `lib/oli/authoring/editing/activity_editor.ex`, `lib/oli/authoring/editing/activity_bank.ex`, `lib/oli/authoring/media_library.ex`.
- Entry-point anchors: `lib/oli_web/controllers/api/resource_controller.ex`, `lib/oli_web/controllers/api/activity_controller.ex`, `lib/oli_web/controllers/api/activity_bank_controller.ex`, `lib/oli_web/controllers/api/media_controller.ex`, `lib/oli/mcp/tools`, `lib/oli/scenarios/directives/edit_page_handler.ex`.
- Existing test anchors: `test/oli/editing/resource_editor_test.exs`, `test/oli/editing/page_editor_test.exs`, `test/oli_web/controllers/api/activity_bank_controller_test.exs`.
- Lexical matching files: 5 lib / 2 test; symbols: `delete_media_items`, `delete_items`, `restore_item`, `delete_bulk`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Deletion can be encoded as a new revision or page JSON edit, not a function named delete; generic edits require explicit review.

### W11: Imports, repairs, and content replacement

- Owning implementation PR: **PR-04**.
- Actions: Archive ingestion/import, Google Doc import, project repair and administrative replacement/removal flows.
- Requirements: FR-008, FR-013, FR-027, FR-029.
- Domain/storage anchors: `lib/oli/google_docs/import.ex`, `lib/oli/interop/ingest.ex`, `lib/oli/authoring/project_repair/repair.ex`.
- Entry-point anchors: `lib/oli_web/live/workspaces/course_author/project_repair_live.ex`, `lib/oli_web/controllers`, `lib/oli/mcp/tools`.
- Existing test anchors: `test/oli/google_docs/import_test.exs`, `test/oli/interop/ingest_test.exs`, `test/oli/authoring/project_repair_test.exs`.
- Lexical matching files: 4 lib / 0 test; symbols: `create_project_from_archive`, `google_doc_imported`, `Repair.repair`. Counts are not runtime calls or exact change sizes.
- Implementation risk: External fetch/storage effects and partially committed repairs cannot be made globally atomic with one PostgreSQL transaction.

### W12: Learner-record interventions

- Owning implementation PR: **PR-06**.
- Actions: Attempt deletion/reset, progress restoration, manual grade changes and instructor/admin regrading.
- Requirements: FR-015, FR-027, FR-029.
- Domain/storage anchors: `lib/oli/delivery/attempts/core.ex`, `lib/oli/delivery/attempts/manual_grading.ex`.
- Entry-point anchors: `lib/oli_web/live/admin/restore_user_progress.ex`, `lib/oli_web/live/progress`, `lib/oli_web/live/manual_grading`.
- Existing test anchors: `test/oli/delivery/attempts/manual_grading_test.exs`, `test/oli_web/live/manual_grading/manual_grading_view_test.exs`.
- Lexical matching files: 5 lib / 3 test; symbols: `delete_resource_attempt`, `apply_manual_scoring`, `delete_resource_accesses_by_section_and_user`, `update_resource_accesses_by_section_and_user`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Some mutations live directly in LiveView, and shared attempt helpers also serve ordinary learning.

### W13: DOT, activation points, and instructor AI recommendation settings

- Owning implementation PR: **PR-05**.
- Actions: Section DOT/activation and instructor recommendation configuration; reuse project/content policies delivered in PR-04.
- Requirements: FR-011.
- Domain/storage anchors: `lib/oli/experiments.ex`, `lib/oli/authoring/course.ex`, `lib/oli/delivery/sections.ex`, `lib/oli/authoring/editing/page_editor.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/content_settings.ex`, `lib/oli_web/live/components/sections/instructor_ai_recommendations_component.ex`, `lib/oli_web/live/workspaces/course_author/experiment_configuration_form.ex`, `lib/oli_web/controllers/api/trigger_point_controller.ex`.
- Existing test anchors: `test/oli/experiments/configuration_test.exs`, `test/oli_web/live/components/sections/instructor_ai_recommendations_component_test.exs`, `test/oli_web/controllers/api/trigger_point_controller_test.exs`.
- Lexical matching files: 3 lib / 2 test; symbols: `update_condition_availability`, `update_condition_availabilities`, `update_section_participation`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Configuration and runtime recommendation/trigger writes share vocabulary; field classification must avoid auditing learner dialogue.

### W14: Saved remixes and publication updates

- Owning implementation PR: **PR-05**.
- Actions: Saved add/remove/move/reorder/visibility/source remixes; applied publication updates and auto-update policy.
- Requirements: FR-012, FR-020.
- Domain/storage anchors: `lib/oli/delivery/remix.ex`, `lib/oli/delivery/sections.ex`, `lib/oli/delivery/updates/worker.ex`.
- Entry-point anchors: `lib/oli_web/live/delivery/remix_section.ex`, `lib/oli/scenarios/directives/remix_handler.ex`.
- Existing test anchors: `test/oli/scenarios/remix_test.exs`, `test/scenarios/delivery/remix_product_sources_test.exs`, `test/scenarios/lti_external_tool/publication_update_test.exs`.
- Lexical matching files: 9 lib / 10 test; symbols: `apply_publication_update`, `update_section_project_publication`, `perform_now`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Existing save already composes several writes; copying its internal captures would multiply events. Background update identity must be defined.

### W15: Discussion moderation and collaboration settings

- Owning implementation PR: **PR-06**.
- Actions: Self/instructor/admin post/thread deletion and moderation; compose discussion/notes configuration already owned by PR-05.
- Requirements: FR-014, FR-022.
- Domain/storage anchors: `lib/oli/resources/collaboration.ex`.
- Entry-point anchors: `lib/oli_web/controllers/api/directed_discussion_controller.ex`, `lib/oli_web/live/components/sections/course_discussions_component.ex`.
- Existing test anchors: `test/oli/resources/collaboration_test.exs`, `test/oli_web/live/collaboration_live_test.exs`.
- Lexical matching files: 10 lib / 6 test; symbols: `soft_delete_post`, `delete_posts`, `disable_all_page_collab_spaces_for_project`, `enable_all_page_collab_spaces_for_section`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Soft-delete overloads and generic update_post can hide unaudited moderation; cascade cardinality needs an explicit contract.

### W16: Section, product, and blueprint lifecycle

- Owning implementation PR: **PR-05**.
- Actions: Section/product/blueprint create/delete/archive; creation from source; preserve section_created.
- Requirements: FR-018, FR-029, FR-037.
- Domain/storage anchors: `lib/oli/delivery.ex`, `lib/oli/delivery/sections.ex`, `lib/oli/delivery/sections/blueprint.ex`, `lib/oli/delivery/section_creation_auditor.ex`.
- Entry-point anchors: `lib/oli_web/controllers/api/product_controller.ex`, `lib/oli_web/controllers/api/blueprint_controller.ex`, `lib/oli_web/live/new_course/new_course.ex`, `lib/oli/scenarios/directives/section_handler.ex`.
- Existing test anchors: `test/oli/delivery/section_creation_test.exs`, `test/oli/delivery/sections/blueprint_test.exs`, `test/oli_web/controllers/api/product_controller_test.exs`, `test/oli/sections_test.exs`.
- Lexical matching files: 12 lib / 85 test; symbols: `create_section`, `create_section_from_source`, `soft_delete_section`, `delete_section`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Multiple creation helpers and shared section storage; nested automatic enrollment must remain semantically distinct.

### W17: Section/product/blueprint settings and student support

- Owning implementation PR: **PR-05**.
- Actions: Schedule/access/registration/content-delivery/survey settings plus student-support configuration across section/product/blueprint types.
- Requirements: FR-018, FR-022.
- Domain/storage anchors: `lib/oli/delivery/sections.ex`, `lib/oli/delivery.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/content_settings.ex`, `lib/oli_web/live/sections/open_free_settings.ex`, `lib/oli_web/live/workspaces/course_author/products/details_live.ex`.
- Existing test anchors: `test/oli/sections_test.exs`, `test/oli/delivery_test.exs`.
- Lexical matching files: 22 lib / 58 test; symbols: `update_section`, `update_delivery_setting`, `create_required_survey`, `delete_required_survey`. Counts are not runtime calls or exact change sizes.
- Implementation risk: High generic update_section fan-out; use field ownership and reviewed dispatch rather than moving every unrelated write at once.

### W18: Enrollment, invitations, and instructor access

- Owning implementation PR: **PR-06**.
- Actions: Enrollment/instructor invitation issuance/acceptance/removal, role changes, suspension and unenrollment, including bulk administration.
- Requirements: FR-019.
- Domain/storage anchors: `lib/oli/accounts.ex`, `lib/oli/delivery/sections.ex`.
- Entry-point anchors: `lib/oli_web/live/users/invitations/users_invite_view.ex`, `lib/oli_web/live/sections`, `lib/oli/scenarios/directives/enrollment_handler.ex`, `lib/oli/scenarios/directives/bulk_create_enroll_users_handler.ex`.
- Existing test anchors: `test/oli/sections_test.exs`, `test/oli/delivery/sections/enrollment_guard_test.exs`, `test/oli/delivery/sections/enrollments_browse_test.exs`.
- Lexical matching files: 23 lib / 113 test; symbols: `enroll`, `update_enrollment`, `update_user_context_role`, `accept_user_invitation`, `accept_user_invitation_via_sso`, `delete_enrollment_invitation_tokens`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Enrollment is also called automatically on launch/creation; actor resolution and event cardinality must be explicit.

### W19: Remaining project settings

- Owning implementation PR: **PR-04**.
- Actions: Visibility, duplication rights, learning model, experiments/alternatives, activity/tool availability and required project surveys.
- Requirements: FR-016.
- Domain/storage anchors: `lib/oli/authoring/course.ex`, `lib/oli/experiments.ex`, `lib/oli/activities.ex`.
- Entry-point anchors: `lib/oli_web/live/projects/customization.ex`, `lib/oli_web/live/projects/visibility.ex`, `lib/oli_web/live/projects/required_survey.ex`, `lib/oli_web/live/workspaces/course_author/experiments_live.ex`, `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`.
- Existing test anchors: `test/oli/course_test.exs`, `test/oli/experiments/configuration_test.exs`, `test/oli/activities/activity_registration_project_test.exs`.
- Lexical matching files: 15 lib / 22 test; symbols: `update_project`, `update_project_attributes`, `upgrade_learning_model`, `create_project_survey`, `delete_project_survey`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Generic project and resource APIs overlap; settings ownership must avoid duplicate captures.

### W20: Authoring defaults, banks, objectives, and curriculum configuration

- Owning implementation PR: **PR-04**.
- Actions: Assessment defaults; activity-bank rules; learning objectives; authoring curriculum settings and relationships.
- Requirements: FR-017.
- Domain/storage anchors: `lib/oli/authoring/editing/page_editor.ex`, `lib/oli/authoring/editing/activity_bank.ex`, `lib/oli/authoring/editing/objective_editor.ex`, `lib/oli/authoring/editing/container_editor.ex`, `lib/oli/resources.ex`.
- Entry-point anchors: `lib/oli_web/controllers/api/objectives_controller.ex`, `lib/oli_web/live/workspaces/course_author/objectives_live.ex`, `lib/oli_web/live/workspaces/course_author/curriculum_live.ex`, `lib/oli/mcp/tools`, `lib/oli/scenarios/directives`.
- Existing test anchors: `test/oli/editing/page_editor_test.exs`, `test/oli/editing/objective_editor_test.exs`, `test/oli_web/controllers/api/activity_bank_controller_test.exs`.
- Lexical matching files: 14 lib / 7 test; symbols: `delete_sub_objective`, `create_revision_from_previous`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Generic revision creation is too low-level for blanket auditing; semantic classification belongs at application commands.

### W21: Gating, prerequisites, and bulk scheduling

- Owning implementation PR: **PR-05**.
- Actions: Create/update/delete gating and prerequisites; set/clear bulk curriculum schedules.
- Requirements: FR-021.
- Domain/storage anchors: `lib/oli/delivery/gating.ex`, `lib/oli/delivery/sections/scheduling.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/gating_and_scheduling.ex`, `lib/oli_web/controllers/api/scheduling_controller.ex`.
- Existing test anchors: `test/oli/delivery/sections/scheduling_test.exs`, `test/oli_web/controllers/api/scheduling_controller_test.exs`, `test/oli_web/live/sections/gating_and_scheduling_test.exs`.
- Lexical matching files: 2 lib / 1 test; symbols: `create_gating_condition_with_index`, `update_gating_condition_with_index`, `delete_gating_condition_with_index`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Bulk scheduling can overlap assessment dates; define event ownership when operations compose.

### W22: Payment administration and certificates

- Owning implementation PR: **PR-06**.
- Actions: Paywall/pricing/discount/payment-code/manual entitlement administration; certificate configuration and administrative grant/revoke.
- Requirements: FR-023, FR-024.
- Domain/storage anchors: `lib/oli/delivery/paywall.ex`, `lib/oli/delivery/certificates.ex`, `lib/oli/delivery/granted_certificates.ex`.
- Entry-point anchors: `lib/oli_web/live/sections/paywall_settings.ex`, `lib/oli_web/live/projects/transfer_payment_codes.ex`, `lib/oli_web/live/certificates/certificate_settings_live.ex`, `lib/oli_web/controllers/granted_certificates_controller.ex`, `lib/oli/scenarios/directives/certificate_action_handler.ex`.
- Existing test anchors: `test/oli/delivery/paywall_test.exs`, `test/oli/delivery/certificates_test.exs`, `test/oli/delivery/granted_certificates_test.exs`, `test/oli_web/controllers/granted_certificates_controller_test.exs`.
- Lexical matching files: 14 lib / 9 test; symbols: `create_payment_codes`, `transfer_payment_codes`, `create_or_update_discount`, `update_payments_for_enrollment`, `update_certificate`, `update_granted_certificate`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Shared section settings plus sensitive payment data. Reconsider splitting only if implementation demonstrates excessive size, with owner agreement.

### W23: Organizations and research-consent configuration

- Owning implementation PR: **PR-03**.
- Actions: Institution, community/publisher lifecycle/configuration/membership and research-consent settings.
- Requirements: FR-025.
- Domain/storage anchors: `lib/oli/institutions.ex`, `lib/oli/groups.ex`, `lib/oli/inventories.ex`, `lib/oli/delivery/research_consent.ex`, `lib/oli/delivery.ex`.
- Entry-point anchors: `lib/oli_web/controllers/institution_controller.ex`, `lib/oli_web/live/community_live`, `lib/oli_web/live/publisher_live`, `lib/oli_web/live/admin/institutions/research_consent_view.ex`.
- Existing test anchors: `test/oli/institutions_test.exs`, `test/oli/groups/community_test.exs`, `test/oli/inventories/publisher_test.exs`, `test/oli_web/live/community_live_test.exs`.
- Lexical matching files: 14 lib / 15 test; symbols: `create_institution`, `update_institution`, `create_community`, `update_community`, `delete_community`, `create_publisher`, `update_publisher`, `delete_publisher`, `update_system_research_consent_form_setting`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Institution module also contains integration configuration; keep organization and integration function ownership explicit inside PR-03.

### W24: LMS, SSO, LTI, external tools, roster, and grade-passback configuration

- Owning implementation PR: **PR-03**.
- Actions: Registration/deployment/platform configuration; external-tool bindings/deep links; roster and grade-passback settings.
- Requirements: FR-025.
- Domain/storage anchors: `lib/oli/institutions.ex`, `lib/oli/lti/platform_external_tools.ex`, `lib/oli/delivery/sections.ex`.
- Entry-point anchors: `lib/oli_web/controllers/registration_controller.ex`, `lib/oli_web/live/admin/external_tools`, `lib/oli_web/live/sections/lti_external_tools.ex`, `lib/oli_web/live/sections/lti_settings.ex`.
- Existing test anchors: `test/oli/institutions_test.exs`, `test/oli/lti/platform_external_tools_test.exs`, `test/oli_web/controllers/registration_controller_test.exs`, `test/scenarios/lti_external_tool/section_configuration_test.exs`.
- Lexical matching files: 7 lib / 11 test; symbols: `create_registration`, `update_registration`, `delete_registration`, `create_deployment`, `update_deployment`, `delete_deployment`, `update_lti_external_tool_activity_deployment`, `create_section_resource_deep_link`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Distributed provider effects and nested deep links; generic integration inputs can carry secrets.

### W25: AI services and API/MCP credentials

- Owning implementation PR: **PR-03**.
- Actions: AI model/service/feature configuration; API/MCP credential creation, status/rotation/revocation where supported.
- Requirements: FR-026.
- Domain/storage anchors: `lib/oli/gen_ai.ex`, `lib/oli/interop.ex`, `lib/oli/mcp/auth.ex`.
- Entry-point anchors: `lib/oli_web/live/gen_ai`, `lib/oli_web/live/api_keys/api_keys_live.ex`, `lib/oli_web/live/admin/mcp_tokens/mcp_tokens_view.ex`, `lib/oli_web/live/projects/mcp_token_manager.ex`.
- Existing test anchors: `test/oli/gen_ai_test.exs`, `test/oli/mcp/auth_test.exs`, `test/oli/mcp/auth_integration_test.exs`.
- Lexical matching files: 8 lib / 17 test; symbols: `create_registered_model`, `update_registered_model`, `delete_registered_model`, `create_service_config`, `update_service_config`, `delete_service_config`, `create_key`, `update_key`, `create_token`, `delete_token`, `update_token_status`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Many inputs intentionally contain credentials; allowlists and marker-secret tests are mandatory.

### W26: Feature flags and rollout controls

- Owning implementation PR: **PR-03**.
- Actions: Feature enable/disable/remove, atomic multi-feature updates, rollout-stage and exemption upsert/delete.
- Requirements: FR-026, FR-029.
- Domain/storage anchors: `lib/oli/scoped_feature_flags.ex`, `lib/oli/scoped_feature_flags/rollouts.ex`.
- Entry-point anchors: `lib/oli_web/live/admin/canary_rollouts_live.ex`.
- Existing test anchors: `test/oli/scoped_feature_flags/audit_integration_test.exs`, `test/oli/scoped_feature_flags/rollouts_test.exs`, `test/oli/scoped_feature_flags_test.exs`.
- Lexical matching files: 4 lib / 16 test; symbols: `enable_feature`, `disable_feature`, `remove_feature`, `set_features_atomically`, `upsert_rollout`, `delete_rollout`, `upsert_exemption`, `delete_exemption`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Existing audit coverage is inside domain helpers; relocation must preserve atomic and cache behavior.

### W27: Persisted user and author preferences

- Owning implementation PR: **PR-06**.
- Actions: Remaining persisted preferences and individual consent-related preference writes, after access/destructive coverage.
- Requirements: FR-028, FR-040.
- Domain/storage anchors: `lib/oli/accounts.ex`.
- Entry-point anchors: `lib/oli_web/live/cookie_preferences_live.ex`, `lib/oli_web/controllers/cookie_consent_controller.ex`, `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`.
- Existing test anchors: `test/oli/accounts_test.exs`, `test/oli_web/user_auth_test.exs`, `test/oli_web/author_auth_test.exs`.
- Lexical matching files: 8 lib / 2 test; symbols: `set_author_preference`, `set_user_preference`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Preference setters are widely shared and sometimes nested in login; apply semantic rather than call-count cardinality.

### W28: Central Audit Log investigation UI and search

- Owning implementation PR: **PR-07**.
- Actions: Readable new/historical event details and search by actor/entity, action, dates and project/section; deleted identity search.
- Requirements: FR-034, FR-035, FR-039.
- Domain/storage anchors: `lib/oli/auditing.ex`, `lib/oli/auditing/browse_options.ex`, `lib/oli/auditing/log_event.ex`.
- Entry-point anchors: `lib/oli_web/live/admin/audit_log_live.ex`, `lib/oli_web/live/admin/audit_log/table_model.ex`.
- Existing test anchors: `test/oli/auditing_test.exs`, `test/oli_web/live/admin/audit_log_live_test.exs`.
- Lexical matching files: 2 lib / 1 test; symbols: `browse_events`, `get_event!`. Counts are not runtime calls or exact change sizes.
- Implementation risk: Search touches historical joins and pagination totals; measure counts and all-history queries rather than assuming partitioning makes them fast.

Project/content DOT policy is also owned by PR-04; W13 in PR-05 extends it to delivery. Discussion/notes configuration belongs to PR-05, while W15 in PR-06 handles moderation. Async foundations belong inside actual PR-04 import/repair implementation; W08 applies them to ClickHouse in PR-06. These shared areas do not create extra PRs.

## Original-event ownership

PR-01 preserves all 16 meanings and compatibility; final relocation/atomicity is owned as follows. Tests must verify the original behavior as well as the enriched contract.

| Existing event | Owning PR |
| --- | --- |
| `user_deleted` | PR-02 |
| `author_deleted`, `author_role_changed`, `account_internal_flag_changed` | PR-03 |
| `project_published` | PR-04 |
| `section_created` | PR-05 |
| `google_doc_imported` | PR-04 |
| `resource_attempt_deleted` | PR-06 |
| `clickhouse_admin_operation_initiated` | PR-06 |
| `feature_flag_enabled`, `feature_flag_disabled`, `feature_flag_removed` | PR-03 |
| `feature_rollout_stage_changed`, `feature_rollout_stage_deleted` | PR-03 |
| `feature_rollout_exemption_upserted`, `feature_rollout_exemption_deleted` | PR-03 |

## Closure evidence required per slice

Before calling an action migrated, replace candidate matches with actual module/function/entry-point ownership and test references, covering each supported channel. Record an exclusion reason for routine learning, derived state and read-only callers. Inspect generic changeset keys and bulk/direct Repo paths, and preserve this inventory as code moves. No broad `other contexts` phase remains: newly discovered actions are assigned to the matching numbered owner or trigger an explicit plan revision. Production volume, runtime privileges and external SQL consumers still need operational evidence rather than source-code inference.
