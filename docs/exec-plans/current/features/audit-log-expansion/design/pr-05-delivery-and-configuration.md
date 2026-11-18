# PR-05 Coverage: Delivery and Configuration - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- FDD: `docs/exec-plans/current/features/audit-log-expansion/fdd.md` (sections 7.1 for retries and 6 for the history conversion)
- Plan: `docs/exec-plans/current/features/audit-log-expansion/plan.md` (Phase 5, MER-6115)
- Scope: `docs/exec-plans/current/features/audit-log-expansion/jira-subtasks.md` (PR-05)
- Inventory: `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md` (W03, W04, W13, W14, W16, W17, W21)
- Predecessors: `docs/exec-plans/current/features/audit-log-expansion/design/pr-03-identity-and-platform-administration.md`, `docs/exec-plans/current/features/audit-log-expansion/design/pr-04-authoring-projects-imports-and-repairs.md`

Status: approved by the owner on 2026-11-18. Source inspected at `3575b5cacc` (last PR-04 commit). Scope aligned with MER-6066 on 2026-11-18 (`phase-5-execution.md`). No code, migration, or database command has run for this design. Implementation evidence belongs in `phase-5-execution.md`, which continues at checkpoint A after approval.

## 1. Slice Summary

Make every supported delivery write that MER-6066 names an audited command: assessment settings (single and bulk), student exceptions, section and product lifecycle and settings, section DOT and instructor recommendations, discussion and notes configuration, saved remixes, publication updates applied to sections, gating, prerequisites, and scheduling. Each command writes the change and its events in one transaction through an audited facade separate from the domain code it calls: three new facades, one per delivery context that owns the data (`Oli.Delivery.Sections.Audited`, `Oli.Delivery.Settings.Audited`, `Oli.Delivery.Gating.Audited`), plus a project-side discussion module in PR-04's `Oli.Authoring.Audited`. Move `section_created` off the legacy adapter into the creation transactions, convert the `settings_changes` history into central v1 events, and drop that table.

In scope (internal blocks, implemented in this order):

1. **Section and product lifecycle (W16).** Creation from every supported path, product creation and duplication, deletion, and archival; `section_created` moved into the audited commands.
2. **Section and product settings (W17, W13, section side of W14).** The restriction of `Sections.update_section/2` with a code-level classification of every `sections` column; edit forms, product details, open-and-free settings, cover image, labels, agenda, required survey, section DOT and instructor recommendations, discussion and notes configuration of sections and of project pages, `apply_major_updates`, and the LTI service fields handed over from PR-03.
3. **Assessment settings and student exceptions (W03, W04).** Single and bulk changes, exception create, update, and delete (single and bulk); the `settings_changes` writers and readers removed.
4. **History conversion (W03).** Migration that converts `settings_changes` into v1 `assessment_setting_changed` events with passwords redacted and drops the table, with a rehearsal.
5. **Remix and publication updates (W14).** `Remix.save` and `apply_publication_update` with the initiating actor carried by the job.
6. **Gating and scheduling (W21).** Gating conditions and student exceptions to them, prerequisites, schedule updates and clearing.

Out of scope:
- All certificate configuration and grants, payment and pricing settings (PR-06). Their `sections` columns stay open in the generic update path until PR-06 closes them (section 3.3).
- Discussion post and thread moderation, enrollment and instructor access (PR-06).
- Runtime trigger invocation (`trigger_point_controller.ex`), DOT conversations, and learner activity.
- Products created by an archive import or by project duplication: part of `project_imported` and `project_duplicated` (PR-04).
- New product behavior and new endpoints. Assessment settings have no "reset to defaults" operation today (section 7, decision D2).

## 2. Requirements Coverage

These are design mappings, not implementation proof. `requirements.yml` gains no evidence entries until real evidence exists. Code and tests carry no requirement or ticket codes.

| Requirement / criteria | This slice's responsibility and planned proof |
| --- | --- |
| FR-009 / AC-028 | `assessment_settings_changed` per assessment for every key of `Fields.assessment_settings()`, diffed against the `section_resources` row locked in the transaction; password as a redaction marker |
| FR-009 / AC-029 | Bulk apply records one event per assessment whose values changed, sharing the operation ID; unchanged and ineligible assessments record nothing |
| FR-009 / AC-030 | No reset operation exists (decision D2); secret handling as AC-028 |
| FR-010 / AC-031, AC-032 | `student_exception_created`, `_updated`, `_deleted` with the instructor or admin as actor and the student as `affected_user_id`; bulk removal records one event per removed exception |
| FR-011 / AC-033 | Section `assistant_enabled`, `page_prompt_template` (`dot_settings_changed`) and `triggers_enabled` (`activation_settings_changed`), section scope; prompts through the PR-04 2,000-character rule |
| FR-011 / AC-034 | `instructor_ai_recommendation_changed` for the toggle and the saved prompt; the trigger-point API and recommendation generation record nothing |
| FR-012 / AC-035, AC-036 | `section_remix_saved` per curriculum entry whose parent, position, `hidden`, or source publication changed, diffed from persisted rows under the section lock; cancel, unsaved edits, and failed saves record nothing |
| FR-018 / AC-047 | `section_created`, `product_created`, `section_deleted`, `section_archived`, `product_archived` with title snapshots |
| FR-018 / AC-048 | `section_settings_changed` and `product_settings_changed` for every column of `Fields.section_settings()`; `update_section/2` closed to them |
| FR-020 / AC-051 | `publication_applied` inside the update transaction with previous and resulting publication refs, project scope, and the initiating author or instructor |
| FR-020 / AC-052 | `publication_update_policy_changed` for product `apply_major_updates`; the project `auto_update_sections` side is PR-04's; jobs carry the initiator's context (section 4.5) |
| FR-021 / AC-053 | `gating_changed` (schedule and always-open conditions, with `affected_user_id` for student exceptions) and `prerequisite_changed` (started, finished, progress); derived index rebuilds record nothing |
| FR-021 / AC-054 | `curriculum_schedule_changed` per section resource whose schedule changed, sharing the operation ID |
| FR-022 / AC-055 | `discussion_settings_changed` (course and page discussion configuration in sections, page discussion configuration in projects), `notes_settings_changed` (the notes toggle); student-support configuration lives on publishers (PR-03) and in the DOT assistant setting (decision D3) |
| FR-025 / AC-061 (section side) | The four LTI service fields mirror the LMS on each launch and record nothing (decision D4); the forms can no longer change them |
| FR-029 / AC-069 | `section_created` keeps its name and details; the legacy adapter keeps only `resource_attempt_deleted` and `clickhouse_admin_operation_initiated` |
| FR-033 / AC-083 to AC-086 | Conversion migration, rehearsal, drop of the table and its writers and readers; settings commands write only central events (section 4.4) |
| FR-035 / AC-092 | Facades add no authorization; checks that live in migrated functions (secure-delivery editor check, section creation authorization) move inside the transaction |
| FR-036 | `Oli.Delivery.Sections.Audited`, `Oli.Delivery.Settings.Audited`, and `Oli.Delivery.Gating.Audited` as independent Boundaries with private implementation modules (section 3.1) |
| FR-037 / AC-097 | Section, product, remix, update, gate, student-exception, assessment-settings, and discussion directives use the represented author or instructor with source `:scenario` |

### 2.1 Caller and write inventory

Gathered at `3575b5cacc` from the callers, changesets, direct `Repo` writes, and route pipelines. Line numbers are indicative. Every checkpoint re-verifies its rows against the diff and records the final mapping in `phase-5-execution.md`. **M** = migrated to an audited command; **C** = composed inside another audited command; **X** = excluded, with the reason.

#### Section and product lifecycle

| Current path | Today | Class |
| --- | --- | --- |
| `Oli.Delivery.create_section/1` (`delivery.ex:39`) via `new_course.ex:373` (in a `Task`) | Authorization, one transaction for the three sources (publication, product, previous section), creator enrollment; `section_created` through `SectionCreationAuditor` in each source branch (`delivery.ex:166,195,215`) | M: `create_section/2`; the event is appended once by the facade for every branch, `SectionCreationAuditor` removed; the `Context` is built in the LiveView before the task |
| LTI early return (`delivery.ex:54`, existing section for the context) | Nothing created | X: no event |
| `OpenAndFreeController.create` (`open_and_free_controller.ex:60`, `:131`) | Own transactions for product and project sources; no audit | M: `create_section/2` with the independent instructor; deep links and post-processing differences kept as today |
| `Blueprint.create_blueprint/5` via `products_view.ex:364`, `products_live.ex:180`, Scenario `product_handler.ex:25`, seeder `seeder/project.ex:410` | Transaction; no actor, no audit | M: `create_product/4` (`product_created`); the seeder uses it with `playwright_setup` |
| `Blueprint.create_blueprint_from_archive/6` inside the ingest transaction | Nested | C: part of `project_imported` |
| `Clone.clone_blueprints` inside `Audited.duplicate_project` | Nested | C: part of `project_duplicated` |
| `Blueprint.duplicate/3` via `details_view.ex:428`, `details_live.ex:458` | `SectionCopy.copy` transaction; no audit | M: `duplicate_product/3` wraps it (`product_created`, `creation_source: "product_copy"`, source `blueprint_id`); `duplicate/3` stays public because `Clone.clone_blueprints`, section creation from a product, open and free, the seeder, and Scenario hooks compose it |
| Scenario `section_handler.ex:95,124,160` | Direct inserts; the product branch calls `Oli.Auditing.capture` and ignores its result | M: `create_section/2` or the facade's Scenario creation with the represented instructor or author |
| `AutomationSetup.create_section` (`automation_setup.ex:280`) | Inside the setup transaction | M: `section_created` with `playwright_setup` |
| `OverviewView` `"delete_section"` (`overview_view.ex:642`) | `update_section(status: :archived | :deleted)`; no transaction | M: `delete_section/2` (`section_archived` when the section has student data, `section_deleted` otherwise, as today) |
| Product status select (`details_view.ex:443`, `details_live.ex:479`) | `status` in the generic form save | M: `product_archived` when it becomes archived; reactivation is a settings change |
| `Sections.soft_delete_section/1` | No production caller | M: removed; its test uses `delete_section/2` |
| `Sections.delete_section/1` via `AutomationSetup.teardown_section`; `teardown_project` `delete_all` | Hard deletes of automation sections | X: automation teardown of its own fixtures |
| `Sections.create_section/1`, `create_section_from_source/2`, `create_section_resources`, `SectionCopy.copy` | Low-level writers used by the commands above, seeders, and 85 test files | C: stay public as generic writers; the caller inventory closes their audited uses (section 3.1) |
| Seeders (`db_seeder.ex`, `seeder/section.ex`, `seeds.exs`, `instructor_dashboard.seed.ex`) | Direct inserts for development and test setup | X: test and development setup |

#### Section and product settings

| Current path | Fields | Class |
| --- | --- | --- |
| `edit_view.ex:196` `"save"` | Raw form params: title, description, welcome title, subtitle, brand, institution (when no deployment), dates, scheduling time, timezone, open-and-free access, paywall, numbering; any castable key reaches the changeset | M: `update_section_settings/4` with the form's allowlist; paywall keys pass through unaudited until PR-06 (section 3.3) |
| `edit_view.ex:224` `"save_labels"` | `customizations` | M |
| `details_view.ex:443`, `details_live.ex:479` (product edit, paywall, and content forms) | Title, status, description, welcome title, subtitle, publisher, paywall, `apply_major_updates`, numbering, `unnumbered_unit_ids` | M: `product_settings_changed`; `apply_major_updates` records `publication_update_policy_changed` |
| `OpenAndFreeController.update` (`open_and_free_controller.ex:232`) | Raw params: title, dates, brand, access | M |
| `CoverImageUpload` (`cover_image_upload.ex:41`) from the section overview and both product views | `cover_image` | M |
| `SchedulingController.update_agenda` (`scheduling_controller.ex:207`) | `agenda` | M (`:api`); its missing access check is a pre-existing gap (section 7) |
| `Sections.create_required_survey`, `delete_required_survey` (`sections.ex:6927`) via `required_survey.ex:59,70` | `required_survey_resource_id`, direct `Repo.update` | M: `create_section_survey/2`, `delete_section_survey/2` |
| `admin/institutions/sections_and_students_view.ex:269` | `institution_id`, direct changeset update | M: `section_settings_changed` (`institution_id` added to the policy) |
| `ai_assistant_component.ex:124,142,161` | `assistant_enabled`, `triggers_enabled`, `page_prompt_template` | M: `update_section_dot/4` |
| `instructor_ai_recommendations_component.ex:93,125` | `instructor_recommendations_enabled`, `instructor_recommendation_prompt_template` | M |
| `course_discussions_component.ex:119,123,172` | Root section resource `collab_space_config` and `contains_discussions` (inside `Repo.transact`) | M: `update_course_discussions/4` |
| `collab_space_config_view.ex:353,371,429,490` (delivery mode) | Section page `collab_space_config`, bulk enable and disable, `contains_discussions` | M: `discussion_settings_changed` per page, one transaction |
| `collab_space_config_view.ex:355,401,459` (authoring mode) → `Collaboration.upsert_collaborative_space/4`, `enable/disable_all_page_collab_spaces_for_project` | New page revision with `collab_space_config` in the working publication; bulk `update_all` of page revisions | M: `Oli.Authoring.Audited` (`update_project_page_discussions/5`, `set_project_discussions/3`), project scope; PR-04 left this writer to PR-05 |
| `notes_component.ex:70,78` → `Collaboration.enable/disable_all_page_collab_spaces_for_section` | `update_all` of page `collab_space_config` | M: `set_section_notes/3`, one `notes_settings_changed` for the section |
| `LtiController.get_and_update_lti_section_details` (`lti_controller.ex:260`) | LTI service fields on every launch | X: dedicated system writer, no event (decision D4) |
| `PostProcessing.apply` (`post_processing.ex:59`), `delivery.ex:437,479` | `contains_discussions`, `contains_explorations`, `contains_deliberate_practice` recomputed | X: derived; a dedicated system writer (section 3.3) |
| `gating.ex:447,481`, `previous_next_index.ex:148`, `sections.ex:3642,4085`, `section_copy.ex:216`, `contained_objectives_builder.ex:41`, `section_resource_migration.ex:154` | Indexes, root pointer, migration markers | X: derived; stay on the restricted `update_section/2` |
| Scenario `section_ops.ex:179` (`change` op, `String.to_atom` keys); `discussion_config_handler.ex`; `certificate_handler.ex:17` | Arbitrary keys; discussion; certificate | M: the facade with source `:scenario` and `String.to_existing_atom`; the certificate directive stays on the generic path (PR-06) |
| `certificate_settings_live.ex:297` | `certificate_enabled` | X here: PR-06 |

#### Assessment settings and student exceptions

| Current path | Today | Class |
| --- | --- | --- |
| `AssessmentSettings.update/5` via `settings_table.ex:672,706,727,738,791,941` | Multi: section resource update, auto-submit adjustment, `settings_changes` rows, depot update; secure-delivery editor check | M: `update_assessment_settings/5`; the event replaces the history rows; auto-submit stays in the transaction |
| `SettingsTable` `"confirm_bulk_apply"` (`settings_table.ex:487`) | Three `update_all` and a `settings_changes` insert, no transaction, result ignored | M: `bulk_update_assessment_settings/5`, one transaction (section 4.3) |
| Scenario `section_ops.ex:66,94,108` (`revise`) | `update/5` with a hidden instructor; fallback to `update_section_resource` for ungraded pages | M: the represented instructor; the fallback uses the restricted `update_section_resource/2` only for non-setting keys |
| `StudentExceptions.set_exception/4` via `student_exceptions_table.ex:613,785,862`, Scenario `student_exception_handler.ex:28` | Create: bare insert; update: transaction with auto-submit maintenance | M: `set_student_exception/5` |
| `StudentExceptions.remove_exception/3`, `remove_exceptions/3` via `student_exceptions_table.ex:588`, Scenario `:32` | Bare delete and `delete_all` | M: `remove_student_exceptions/4`, one transaction, one event per removed exception |
| `Settings.update_student_exception/3` via `student_exceptions_table.ex:685` | Bare update | M: through `set_student_exception/5` |
| `Delivery.create_delivery_setting`, `update_delivery_setting`, `upsert_delivery_setting` (`delivery.ex:343-404`) | No lib caller; used by tests | M: removed; tests use a fixture in `test_helpers.ex` |
| `Settings.bulk_insert_settings_changes`, `insert_settings_change`, `fetch_all_settings_changes`, `SettingsChanges` | History writers and test reader | Removed (block 4) |
| `Sections.update_section_resource/2` (`sections.ex:1600`) | Generic update of any section resource field | Restricted: setting, gating, remix, and discussion fields return `:protected` (section 3.3) |
| `instructor_dashboard.seed.ex:212` | Dates on section resources | X: development seed task, through a fixture writer |

#### Remix and publication updates

| Current path | Today | Class |
| --- | --- | --- |
| `Remix.save/2` via `remix_section.ex:551,604`, Scenario `remix_handler.ex:78,134` | One transaction: container materialization in the base project, blueprint container edits, curriculum rebuild under the section lock, deep links; the instructor `User` is never passed | M: `save_remix/3` with the LiveView's actor; one event per changed entry |
| Materialized containers and blueprint container edits inside the save | Authoring writes in the base project | C: part of the remix; creation and title edits are not audited (PR-04 rule) |
| `Updates.apply_publication_update/2` via `Updates.Worker`, Scenario `update_handler.ex:49,97` | Reads the current publication before the lock; transaction; cache and broadcast after commit | M: `apply_publication_update/3`; the current publication is read after the lock |
| `Publishing.push_publication_update_to_sections/4` via `publish_live.ex:202`, `publish_view.ex:237` | One job per section after the publication commits; no actor | M: the job carries the publishing author's context |
| `ManageSourceMaterials` `"apply_update"` (`manage_source_materials.ex:205`) | Job without actor; `Mount.for` actor discarded | M: the job carries the instructor's or admin's context |
| `Sections.apply_publication_update/2` (`sections.ex:4645`) | Legacy duplicate, called only from `publication_update_test.exs:325` | M: removed; that test uses the audited path |

#### Gating and scheduling

| Current path | Today | Class |
| --- | --- | --- |
| `Gating.create/update/delete_gating_condition_with_index` via `gating_condition_store.ex:572,598,659` | Transaction, section lock, before-state under the lock, index rebuild when needed | M: `create_gate/3`, `update_gate/4`, `delete_gate/3` |
| `Gating.create/update/delete_gating_condition` (no index) via Scenario `gate_handler.ex:27,112`, seeders, `gating_condition_fixture` (`test_helpers.ex:242`) | Bare writes; the Scenario rebuilds the index separately | M: the Scenario uses the facade; seeders use it with `playwright_setup`; the fixture keeps a test-only writer in `test/support` |
| `Gating.duplicate_gates` inside `SectionCopy.copy` | Copy at creation | C: part of the section creation |
| `Scheduling.update/3` via `scheduling_controller.ex:172` | One raw `UPDATE ... FROM (VALUES ...)`, no lock, no before-state; cache and async depot clear; an empty update returns early and only clears caches | M: `update_schedule/4`: section lock, before-state select, the same statement, one event per changed row; the empty update keeps its early return and records nothing |
| `Scheduling.clear/1` via `scheduling_controller.ex:194` | Multi `update_all` | M: `clear_schedule/2`, one event per row that had dates |

## 3. Responsibilities & Boundaries

### 3.1 Facade and Boundary topology

**Criterion: one facade per context that owns the written data** (owner decision 2026-11-18, after independent reviews by two models). It is the criterion behind PR-04's facades: `Oli.Activities` and `Oli.Experiments` got their own facades although authoring screens edit them, because they are contexts with their own tables, while `Oli.Authoring.Audited` kept one facade split into private modules. `Oli.Delivery` is a folder of such contexts, not one context, so it gets one facade per context:

| Facade | Private modules (`lib/oli/delivery/<context>/audited/`) | Data it writes |
| --- | --- | --- |
| `Oli.Delivery.Sections.Audited` | `Lifecycle`, `SectionSettings`, `Discussions` (course and page configuration, notes), `Remix`, `Updates`, `Scheduling`, `Support` | `sections`, `section_resources`, `sections_projects_publications`, deep links |
| `Oli.Delivery.Settings.Audited` | `AssessmentSettings`, `StudentExceptions`, `Support` | `section_resources` assessment fields, `delivery_settings` |
| `Oli.Delivery.Gating.Audited` | `Gates`, `Support` | `gating_conditions`, the derived gating index |
| `Oli.Authoring.Audited` (PR-04, extended) | `Discussions` | Project page revisions' `collab_space_config` |

Each public module holds its commands' `@doc`, `@spec`, guards, and `{:error, :invalid_request}` fallback, and delegates to its private modules; each module's header names where each moved write came from. The `Support` modules stay private to their facade: event recording itself is `Oli.Auditing`, and the lock and before-state reads they share are small. PR-06 follows the same criterion: enrollment joins `Sections.Audited`, and payments, certificates, and learner records get their own facades.

Each new facade declares `use Boundary, top_level?: true, exports: [], check: [out: false]` and is added to `deps` in `lib/oli.ex`, `lib/oli_web.ex`, `lib/oli/constellation.ex`, and `test/support/live_component_tests.ex`. At checkpoint A, a temporary forbidden reference from an `Oli` module verifies each facade (recorded, not committed). The Boundary blocks the legacy boundaries from the private modules; it does not check calls between facades (`check: [out: false]`), so no facade calls another's private modules, and the final caller inventory verifies it.

| Module | Moves into a facade | Stays public |
| --- | --- | --- |
| `Oli.Delivery` | `create_section/1` with its private creation steps (`Sections.Audited`); `SectionCreationAuditor` removed | `SectionCreation` loading and authorization helpers, reads |
| `Blueprint` | `create_blueprint/5` (`Sections.Audited`) | `duplicate/3` (wrapped by `duplicate_product`, composed by `Clone`, creation, open and free, seeders, Scenario hooks), `create_blueprint_from_archive/6` (composed by the ingest), reads |
| `Sections` | `create_required_survey`, `delete_required_survey`, `soft_delete_section` (removed), `apply_publication_update/2` (removed) | `create_section*`, `create_section_resources`, reads; `update_section/2` and `update_section_resource/2` restricted (section 3.3) |
| `AssessmentSettings`, `Settings` | `update/5` and its Multi (`Settings.Audited`); the history writers and reader (removed) | reads, combined-settings resolution |
| `StudentExceptions`, `Settings`, `Oli.Delivery` | `set_exception`, `remove_exception(s)`, `update_student_exception` (`Settings.Audited`); the `*_delivery_setting` writers (removed) | reads |
| `Oli.Resources.Collaboration` | `enable/disable_all_page_collab_spaces_for_section` (`Sections.Audited`); `upsert_collaborative_space`, `enable/disable_all_page_collab_spaces_for_project` (`Authoring.Audited`) | reads; post writers (PR-06) |
| `Remix` | `save/2` (`Sections.Audited`) | state operations (`init`, moves, toggles), reads |
| `Updates` | `apply_publication_update/2` (`Sections.Audited`) | diffs, strategies, `ensure_section_resource_exists` |
| `Gating` | every condition writer, with and without index (`Gating.Audited`) | reads, index rebuild (called inside the commands), `duplicate_gates` |
| `Scheduling` | `update/3`, `clear/1` (`Sections.Audited`) | reads |

`Sections.create_section*`, `create_section_resources`, and `SectionCopy.copy` stay public: seeders and 85 test files use them for setup, and the commands compose them. The final caller inventory greps their uses and classifies each.

### 3.2 Responsibilities

- **Facade:** owns the transaction (or composes into the caller's), locks, the before-state read, the diff, event construction, and safe errors. Adds no authorization; checks that lived in a moved function (secure-delivery editor check, section creation authorization) run inside the transaction as today.
- **Private modules:** the moved writes, unchanged except for taking the transaction from the facade.
- **Domain modules:** reads, state operations, locks, creation helpers, and system-derived writes.
- **Transport:** builds the `Context`, calls the facade, and runs broadcasts, depot initialization, cache invalidation, and redirects after commit. Every LiveView that now calls the facade handles non-changeset errors with a flash (to the parent with `{:flash_message, ...}` for components rendered inside another view) and renders failed controls from the saved value.

### 3.3 Section column classification and the restricted generic writers

The classification reuses the field policy that PR-01 already wrote for `Oli.Delivery.Sections.Section` in `Fields.schema_sources/0`. A new internal module, `Oli.Delivery.Sections.SectionFields`, derives three disjoint sets from it:

| Set | Columns | Writable through |
| --- | --- | --- |
| Audited | `Fields.section_settings()`, `dot_activation()` section keys, `publication()` (`apply_major_updates`), `support_configuration()` (`contains_discussions`), plus `institution_id`, `unnumbered_unit_ids` | Facade commands only |
| Open for PR-06 | `Fields.payment_settings()`, `pricing()`, `certificate_settings()` section keys (`certificate_enabled`) | `update_section/2` until PR-06 moves them |
| LMS-supplied | `grade_passback_enabled`, `line_items_service_url`, `nrps_enabled`, `nrps_context_memberships_url` | The LTI launch's system writer only (decision D4) |
| System-derived | Indexes, root pointer, migration markers, `contains_explorations`, `contains_deliberate_practice`, and the creation-only identity columns already excluded in `Fields` | `update_section/2` (indexes, markers) or creation |

- `update_section/2` and `update_section!/2` accept only the open and system-derived keys; any other key returns `{:error, :protected}` (`update_section!` raises). `contains_discussions` is audited but also recomputed by post-processing: `PostProcessing` gets a dedicated system writer for the three `contains_*` flags, and the caller inventory keeps it to post-processing.
- `update_section_resource/2` rejects the keys of `Fields.assessment_settings()`, `gating()`, `remix()`, and `collab_space_config`; its remaining callers write display or creation fields.
- A test fails when a `sections` column is in no set or in more than one, so a new column must be classified (as `field_policy_drift_test.exs` does for events).
- Commands that save a form receive the form's allowlist, built by the transport from the fields the screen renders for that user. Payment fields enter the allowlist only where the screen offers them to that role today: for admins in `EditView` and `DetailsLive`, for the template's author in `DetailsView`, whose paywall form is enabled for them. A form that mixes audited and open keys writes them in one update and records only the audited diff; PR-06 adds the paywall events to the same command. This closes the mass assignment confirmed on 2026-11-18 (`phase-5-execution.md`): today `EditView`, both product views, and `OpenAndFreeController.update` pass raw params to `update_section/2`, so any castable field can be pushed in the event.
- Client keys are never converted with `String.to_atom`; the Scenario `change` op uses `String.to_existing_atom` and the facade's full allowlist.

The test of the classification covers the four sets.

## 4. Interfaces & Signatures

Commands follow the PR-02 shape: a wrapper that owns the transaction and returns `{:error, :nested_transaction}` inside one, and a `*_multi/4` only where a caller composes. Function-style transactions (section creation, remix, updates) append with `Auditing.build/2` and `Auditing.insert/1` or `insert_all/1`, rolling back on error.

```elixir
@type command_error ::
        :invalid_request | :not_found | :nested_transaction | :protected
        | Ecto.Changeset.t() | Oli.Auditing.Error.t() | term()
```

Sections 4.1, 4.2, and 4.5 are `Oli.Delivery.Sections.Audited`; 4.3 is `Oli.Delivery.Settings.Audited`; 4.6 splits between `Oli.Delivery.Gating.Audited` (gates) and `Sections.Audited` (schedule).

### 4.1 Lifecycle

```elixir
@spec create_section(Context.t(), SectionCreationRequest.t()) :: {:ok, pos_integer(), String.t()} | {:error, command_error()}
@spec create_product(Context.t(), pos_integer(), map(), keyword()) :: {:ok, Section.t()} | {:error, command_error()}
@spec duplicate_product(Context.t(), Section.t(), map()) :: {:ok, Section.t()} | {:error, command_error()}
@spec delete_section(Context.t(), Section.t()) :: {:ok, Section.t()} | {:error, command_error()}
```

- `create_section` keeps `Delivery.create_section/1`'s result (`{:ok, id, slug}`), authorization, LTI early return, sources, and creator enrollment, and appends `section_created` with the current details (`section_title`, `type`, `base_project_id`, `creation_source`, `copied_groups`, `blueprint_id`). The open-and-free controller calls it with its own source handling preserved (no deep links or post-processing where it has none today). The creator's enrollment is a side effect of the creation, not a separate event.
- Events use the entity of the section's type: `section_*` for enrollable sections, `product_*` for blueprints, labeled "Template" in the Audit Log (decision D1). Archival records `status` before and after.
- `delete_section` keeps the overview rule: archive when the section has student data, delete (status `:deleted`) otherwise.

### 4.2 Settings, DOT, discussions, notes

```elixir
@spec update_section_settings(Context.t(), Section.t(), map(), [atom()]) :: {:ok, Section.t()} | {:error, command_error()}
@spec update_section_dot(Context.t(), Section.t(), map(), [atom()]) :: {:ok, Section.t()} | {:error, command_error()}
@spec create_section_survey(Context.t(), Section.t()) :: {:ok, Section.t()} | {:error, command_error()}
@spec delete_section_survey(Context.t(), Section.t()) :: {:ok, Section.t()} | {:error, command_error()}
@spec update_course_discussions(Context.t(), Section.t(), map(), [atom()]) :: {:ok, Section.t()} | {:error, command_error()}
@spec update_page_discussions(Context.t(), Section.t(), [pos_integer()], map()) :: {:ok, term()} | {:error, command_error()}
@spec set_section_notes(Context.t(), Section.t(), boolean()) :: {:ok, non_neg_integer()} | {:error, command_error()}

# Oli.Authoring.Audited (project pages)
@spec update_project_page_discussions(Context.t(), Project.t(), String.t(), map(), Author.t()) :: {:ok, map()} | {:error, command_error()}
@spec set_project_discussions(Context.t(), Project.t(), map() | :disabled) :: {:ok, non_neg_integer()} | {:error, command_error()}
```

| Changed keys | Event |
| --- | --- |
| `Fields.section_settings()` keys, `institution_id`, `unnumbered_unit_ids` | `section_settings_changed` / `product_settings_changed` |
| `status` to `:archived` / `:deleted` | `*_archived` / `*_deleted` (section 4.1) |
| `apply_major_updates` | `publication_update_policy_changed` |
| `assistant_enabled`, `page_prompt_template` | `dot_settings_changed` (section scope) |
| `triggers_enabled` | `activation_settings_changed` (section scope) |
| `instructor_recommendations_enabled`, `instructor_recommendation_prompt_template` | `instructor_ai_recommendation_changed` |
| Root `collab_space_config` subfields, `contains_discussions` | `discussion_settings_changed` (section) |
| Page `collab_space_config` | `discussion_settings_changed` per page (entity `:resource`) |
| Notes toggle | `notes_settings_changed`, one for the section, with the number of pages changed in details |
| Project page `collab_space_config` (one page) | `discussion_settings_changed` per page, project scope, with previous and resulting revisions |
| Project bulk enable or disable | `discussion_settings_changed`, one for the project, with the number of pages changed in details |

- Each command locks the section row (`FOR NO KEY UPDATE`), reads the before-state, writes, diffs under the family policy, and appends one event per family that changed. A write that changes nothing writes nothing.
- The project commands lock the working-publication mappings of the pages they change before reading the before-state, as PR-04's `Support.changing/5` does, and keep `upsert_collaborative_space`'s revision behavior.
- Prompts follow the PR-04 rule: recorded up to 2,000 characters with `prompt_truncated`. `instructor_recommendation_prompt_template` and `page_prompt_template` join `DotPolicy`'s prompt handling instead of a second policy.
- `Section.changeset` replaces the `customizations` embed whole; the diff compares its subfields.

### 4.3 Assessment settings and student exceptions

```elixir
@spec update_assessment_settings(Context.t(), Section.t(), pos_integer(), map(), map()) :: {:ok, SectionResource.t()} | {:error, command_error()}
@spec bulk_update_assessment_settings(Context.t(), Section.t(), pos_integer(), [pos_integer()], map()) :: {:ok, non_neg_integer()} | {:error, command_error()}
@spec set_student_exception(Context.t(), Section.t(), pos_integer(), pos_integer(), map()) :: {:ok, StudentException.t()} | {:error, command_error()}
@spec remove_student_exceptions(Context.t(), Section.t(), pos_integer(), [pos_integer()]) :: {:ok, non_neg_integer()} | {:error, command_error()}
```

- **Single update:** the existing Multi, with the history step replaced by the event. The before-state is the locked `section_resources` row, not the cached depot read, so derived changes (the other date, `late_policy` expanded to `late_start` and `late_submit`) appear in one event as the persisted fields that changed. Auto-submit adjustment stays inside the transaction; the depot update moves after commit.
- **Bulk apply:** moves from `SettingsTable` into the facade without changing what it writes (the three updates and their eligibility rules: graded pages except the base, non-adaptive for `replacement_strategy`, unstarted for `batch_scoring`). One transaction: lock the target rows `FOR NO KEY UPDATE` in ID order, select their before-state in one query, run the updates, select the after-state, and insert one event per assessment that changed with `Oli.Auditing.insert_all/1`. The depot update runs after commit. Auto-submit is not adjusted, as today.
- **Exceptions:** create, update, and delete each run in one transaction. The student is `affected_user_id`; the actor is the instructor or admin from the LiveView, which today does not pass its user to `StudentExceptionsTable` and will. Update keeps its auto-submit maintenance inside the transaction. Bulk removal deletes the rows it locked and records one `student_exception_deleted` per row, in one insert.
- `password` is recorded only as the redaction marker, in all four commands.

### 4.4 History conversion

One migration, generated with `mix ecto.gen.migration convert_settings_changes_to_audit_events`, with explicit `up/0` and `down/0`:

- **`up/0`:** a single `INSERT ... SELECT` into `audit_log_events` of one v1 `assessment_setting_changed` row per `settings_changes` row: new central ID from the sequence, `legacy_source = 'settings_changes'`, `legacy_id` = the original ID, original `inserted_at`, actor columns from `user_type` and `user_id` (`:author` to an author, `:instructor` to a user; no FK on `user_id`, so a missing account keeps its ID), `section_id` and `resource_id` scope, and `key`, `old_value`, `new_value` in details with the redaction marker for `password` values. An anti-join on `(legacy_source, legacy_id)` makes it restartable. Then a reconciliation count (source rows = converted rows) before `DROP TABLE settings_changes`; a mismatch raises and rolls back.
- **`down/0`:** recreates `settings_changes` with its original columns and foreign keys, inserts the converted rows back with their original IDs and the redaction marker where a password was, resets its ID sequence, and deletes the converted v1 rows under `SET LOCAL oli.audit_log_allow_mutation = 'on'`. Passwords are not recoverable (owner decision 2026-11-18).
- **Rehearsal:** `test/support/settings_changes_conversion_rehearsal.exs`, following `test/support/audit_log_migration_rehearsal.exs`, on a newly created disposable database with about 440,000 synthetic rows (both user types, passwords, missing accounts, IDs with gaps, boundary timestamps): `up/0`, duration, locks, WAL bytes, rollback, roll-forward. If `up/0` exceeds 60 seconds, plan B is batched inserts by ID range with the same anti-join, before the drop.
- Removed with it: the `SettingsChanges` schema, the three `Settings` history functions, and the test readers, rewritten as audit assertions (`settings_live_test.exs`, `secure_delivery_settings_test.exs`). `log_event.ex` keeps `settings_changes` as a provenance value; the PR-01 migration, which reads the table for its partition range, runs before this one on a fresh database.
- Before release: confirm with operations that nothing outside the repository reads `settings_changes`, and add the step to the runbook Preflight.

### 4.5 Remix and publication updates

```elixir
@spec save_remix(Context.t(), Remix.State.t(), Author.t() | nil) :: {:ok, Section.t()} | {:error, command_error()}
# Remix.save(state, author \\ nil) moves behind the facade; the LiveView and the Scenario call save_remix/3 with the author they pass today
@spec apply_publication_update(Context.t(), Section.t(), pos_integer()) :: {:ok, Section.t()} | {:error, command_error()}
@spec enqueue_publication_update(Context.t(), Section.t(), pos_integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
```

- **Remix:** the command locks the section first (the same row `rebuild_section_curriculum` locks, so lock order does not change), reads the persisted curriculum (parent, position, `hidden`, numbering per resource) and the pinned publications, runs the moved save, reads them again, and records one `section_remix_saved` per resource whose values changed, matched by `resource_id`: added (no before), removed (no after), moved, hidden or shown, or source publication changed (`source` ref). One `insert_all` per save. The author argument is still the one materialization needs; the actor comes from the `Context`, so an LTI instructor who is a `User` is the actor. Cancel and unsaved state write nothing.
- **Publication update:** the current publication is read after `lock_section!`, inside the transaction (today it is read before the lock). When it already equals the target publication, the update runs as today but records nothing. Otherwise `publication_applied` records project scope and `previous` and `resulting` publication refs. A failed update rolls back and records nothing; the worker's retries are unchanged.
- **Job context:** `Context` gains `to_job_args/1` and `from_job_args/1`, which serialize the actor kind, ID, snapshot, and operation ID, and rebuild a context with source `:job` and `parent_operation_id` set to the initiating operation, without a query (a deleted initiator keeps the snapshot). `push_publication_update_to_sections` takes the publishing author's context; `ManageSourceMaterials` the instructor's or admin's. Jobs enqueued before deployment have no context; the worker records them with the system actor `scheduled_maintenance` and source `:job`.
- `apply_major_updates` changes record `publication_update_policy_changed` (section 4.2).

### 4.6 Gating and scheduling

```elixir
@spec create_gate(Context.t(), Section.t(), map()) :: {:ok, GatingCondition.t()} | {:error, command_error()}
@spec update_gate(Context.t(), Section.t(), GatingCondition.t(), map()) :: {:ok, GatingCondition.t()} | {:error, command_error()}
@spec delete_gate(Context.t(), Section.t(), GatingCondition.t()) :: {:ok, GatingCondition.t()} | {:error, command_error()}
@spec update_schedule(Context.t(), Section.t(), [map()], String.t()) :: {:ok, non_neg_integer()} | {:error, command_error()}
@spec clear_schedule(Context.t(), Section.t()) :: {:ok, non_neg_integer()} | {:error, command_error()}
```

- Gates (`Gating.Audited`) keep `with_gating_index`: section lock, before-state under the lock, index rebuild when the gated resource changes. `schedule` and `always_open` record `gating_changed`; `started`, `finished`, and `progress` record `prerequisite_changed`, with the source resource in the changes. A student exception carries `affected_user_id`; deleting a top-level gate deletes its exceptions and records one event per deleted condition. The index rebuild records nothing.
- `update_schedule` (`Sections.Audited`) keeps the early return of an empty update (caches cleared, no event) and adds the section lock and a before-state select of the submitted IDs to today's single statement, and records one `curriculum_schedule_changed` per row whose schedule fields changed, in one insert. `clear_schedule` records one event per row that had dates. Cache and depot invalidation run after commit, as today.
- An assessment date edited from the assessment settings table records `assessment_settings_changed`, not a schedule event: each command records its own write.

### 4.7 Catalog, field policy, and context changes

- Relabel the `product_*` events and the `:product` entity as "Template" (D1). Remove the never-emitted `blueprint_created`, `blueprint_deleted`, `blueprint_archived`, `blueprint_settings_changed` (D1), `assessment_settings_reset` (D2), and `student_support_settings_changed` (D3) from `definitions.ex`, `event_examples.ex`, and `released_event_names.txt`, as PR-04 did with `project_ownership_changed`: the story has not reached production.
- `section_settings` gains `institution_id` and `unnumbered_unit_ids`; `support_configuration` gains detail key `page_count`; `remix` uses the existing fields.
- `Context.to_job_args/1`, `from_job_args/1`.
- The legacy adapter drops `section_created`; `SectionCreationAuditor` and its application environment key are removed, and the rollback test uses the `pg_temp` trigger.
- No new system actor.
- Regenerate `docs/design-docs/audit-log-events.md` at every checkpoint that changes the catalog.

## 5. Data Flow & Edge Cases

Main flow: the transport builds `Context.for_actor(actor, source: :ui | :api | :scenario)`; the facade opens or joins the transaction, locks, reads the before-state, runs the moved write, diffs under the field policy, appends events (any failure rolls everything back), and the transport runs depot updates, broadcasts, and redirects after commit.

| Situation | Required result |
| --- | --- |
| Validation, authorization, or secure-delivery refusal | No change, no event; the existing error reaches the UI |
| Audit insert failure | Mutation rolled back; flash; the control renders the saved value |
| Form save with no value change | No event |
| Generic `update_section/2` with an audited key | `:protected`; nothing written |
| Bulk apply with some assessments unchanged or ineligible | Events only for assessments that changed |
| Exception created with no override values | `student_exception_created` with empty changes (lifecycle event) |
| Bulk exception removal including already-removed students | Events only for deleted rows |
| Password changed | Redaction marker before and after; never the value |
| LTI launch on an existing section | Service fields synced from the LMS, no event (decision D4) |
| Remix canceled or left unsaved | No write, no event |
| Remix save failing at deep links or rebuild | Whole save rolled back, no events |
| Remix that only reorders | Events for the entries whose position changed |
| Publication update applied twice (double click, rerun after commit) | Second run finds the target publication applied and records nothing |
| Publication update failing on every attempt | No event; Oban and logs as today |
| Update job enqueued before deployment | `scheduled_maintenance` system actor |
| Gate edit that changes the gated resource | One event; the index rebuild records nothing |
| Schedule update with unchanged rows | Events only for changed rows |
| Section or product renamed or deleted later | Event-time snapshots unchanged |

**Behavior changes callers will see:** the audited writes fail when the audit insert fails; `update_section/2` and `update_section_resource/2` reject audited keys, so raw form params can no longer change fields outside each form; bulk assessment apply, exception create and delete, notes toggle, required survey, and schedule updates become transactional; schedule updates take the section lock; the publication update reads the current publication under the lock; the depot update of a single assessment change moves after commit; products record creation; the `settings_changes` table no longer exists.

## 6. Test Plan

Same policy as PR-03 and PR-04: unrelated fixtures need no audit; each command gets tests of its mutation-and-event transaction; every migrated caller (LiveView, controller, worker, Scenario directive, seeder) gets a test asserting its event, actor, and source with `assert_audited/2` or `audit_events/2`, added to the existing test when one exercises the path. Paths that must record nothing get an explicit `audit_events(...) == []` scoped to their entities. Audit-insert failures use the `pg_temp` trigger with `capture_log`; concurrency uses `Sandbox.unboxed_run` with cleanup of committed audit rows under the mutation override.

- Unit and component:
  - `SectionFields` classification completeness; `update_section/2` and `update_section_resource/2` rejection of each audited family; Scenario keys with unknown atoms.
  - `Context.to_job_args/1` and `from_job_args/1` round trip, including a deleted initiator.
  - Remix diff: add, remove, move, reorder, hide, source change, and combinations.
  - Catalog examples and contracts for every changed event; field-policy drift; `released_event_names.txt` without the removed names.
- Integration, per block:
  - **Lifecycle:** each creation source and caller (NewCourse with user and admin, open and free, products from both views, duplication, Scenario, automation), archive versus delete, product archive and reactivation, rollback on audit failure (replacing the `SectionCreationAuditor` stub), LTI early return without event.
  - **Settings:** each form and component, mixed audited and open keys, no-op saves, prompts and truncation, discussion and notes toggles, project page discussion edits and bulk toggles from the authoring view, required survey, agenda, institution change, `apply_major_updates`.
  - **Assessment and exceptions:** every setting through the table, derived date changes, auto-submit rollback, secure-delivery refusal, bulk with mixed eligible, ineligible, and unchanged targets, exception create, update, delete, bulk removal, actor versus student, password markers.
  - **History conversion:** a migration test of `up/0` and `down/0` on synthetic rows (types, missing accounts, passwords, restart), plus the rehearsal script on a disposable database.
  - **Remix and updates:** LiveView save and cancel, LTI instructor actor, Scenario, failed save, publication update from the publish views, the manage view, the worker, and the Scenario; already-applied rerun; failure; major and multi-source regressions.
  - **Gating and scheduling:** create, update, delete with and without index changes, student exceptions, prerequisites, cascade of exceptions, schedule update and clear through the API, unchanged rows, rollback.
  - The regression command in `plan.md` phase 5, plus `test/oli_web/live/sections/assessment_settings/settings_live_test.exs`, `test/oli_web/live/remix_section_test.exs`, `test/oli_web/live/manage_source_materials_live_test.exs`, `test/oli_web/controllers/open_and_free_controller_test.exs`, `test/oli_web/live/products/details_view_test.exs`, `test/oli/delivery/gating_test.exs`, and `test/oli/delivery/settings/auto_submit_custodian_test.exs`.
- Manual checks:
  - Boundary forbidden-reference check for each new facade.
  - Rehearsal timing against the 60-second threshold.
  - Latency at checkpoint G: single assessment change, bulk apply over a section with many assessments, remix save of a large curriculum, publication update, schedule update of a full curriculum. Review threshold `max(10 ms, 20% of baseline p95)`.
  - Full `mix test` at the final gate (shared helpers, Scenario handlers, and seeders change).

Database safety: `mix test` targets `oli_test` after checking `DATABASE_URL` is unset. The conversion migration runs against `oli_dev` only with owner approval and a prior `pg_dump -Fc` backup under `~/db_backups/`.

## 7. Risks & Open Questions

- Risks:
  - **Generic writers.** `create_section*`, `create_section_resources`, `SectionCopy.copy`, and the restricted `update_section/2` and `update_section_resource/2` stay public. The final caller inventory greps every use.
  - **Bulk and remix cost.** Bulk apply and large remixes add one before-state and one after-state select plus one event insert per batch; checkpoint G measures them.
  - **Lock additions.** Schedule updates gain the section lock that gates, remix, and updates already take; the facade locks the section first in every command that writes section resources, so the order matches.
  - **Pre-existing, to verify with a temporary test:** `SchedulingController.update_agenda` skips the `can_access_section?` check the other actions use. If confirmed, it goes to a TRIAGE ticket with the owner's agreement; this PR records the change without fixing it.
  - **TRIAGE-2569:** admin live navigation can skip role-specific plugs; the admin section and product views inherit it.
  - **Size.** Three new facades plus a module in `Oli.Authoring.Audited`, many LiveViews, and a data migration. Checkpoints A to G keep review incremental.
  - **Stacked changes in `Oli.Authoring.Audited`.** The project-side discussion commands add to PR-04's facade; changes PR-04 receives in review are merged upward and resolved there.
- Owner decisions (2026-11-18, scope check): `settings_changes` converted and dropped; publication updates as in section 4.5; all certificate configuration in PR-06; the key inventory as the classification of section 3.3.
- Owner decisions (2026-11-18, design review):
  - **D1.** Sections of type `:blueprint` (blueprints in the domain, products in routes and modules, course section templates in the UI) record `product_*` events with entity type `:product`, consistent with the payment family; their catalog labels and descriptions say "Template" (for example "Template created"), as do the entity labels the Audit Log shows. The four `blueprint_*` names are removed.
  - **D2.** The assessment settings UI and domain have no reset-to-defaults operation, and this PR adds none; `assessment_settings_reset` is removed from the catalog. Returning a setting to its earlier value by hand records `assessment_settings_changed`, and the secret rule applies through that event.
  - Publication-update jobs enqueued before the deployment, which carry no context, record `publication_applied` with the system actor `scheduled_maintenance` and source `:job` (section 4.5).
  - Three facades, one per delivery context that owns the data, plus project-side discussions in `Oli.Authoring.Audited` (section 3.1).
  - The mass assignment in the section and template edit forms is fixed in this PR through the form allowlists of section 3.3, without a separate TRIAGE ticket.
  - **D3.** Sections have no student-support configuration. Support email and knowledge-base links live on publishers (`publisher_settings_changed`, PR-03); the student DOT assistant, discussions, and notes have their own events in this PR. `student_support_settings_changed` is removed from the catalog.
  - **D4.** `grade_passback_enabled`, `line_items_service_url`, `nrps_enabled`, and `nrps_context_memberships_url` are written only by the LTI launch, from the LMS claims, through a dedicated system writer that accepts only those four keys and records no event: the values mirror the LMS, and the launching user may be a student. `update_section/2` and every form allowlist reject them.

## 8. Definition of Done

### Design gate

- [x] Requirement coverage is explicit (section 2), with excluded scope distinguished.
- [x] Interfaces are concrete (section 4), including actor rules, event mapping, and composition inside existing transactions.
- [x] Test plan covers main and edge paths (section 6).
- [x] Validation passes (`validate_work_item.py --check design`).
- [x] Owner decisions D1 to D4 recorded in section 7.
- [x] Owner approves the design before checkpoint A (2026-11-18).

### Implementation checkpoints after approval

Each checkpoint pauses for owner review, keeps `phase-5-execution.md` current, and is not permission to commit.

1. **A — Lifecycle.** `Oli.Delivery.Sections.Audited` with the Boundary check; catalog removals; creation from every source, products, duplication, deletion and archival; `section_created` off the legacy adapter.
2. **B — Section settings.** `SectionFields` and the restricted generic writers; edit forms, product details, open and free, cover image, labels, agenda, survey, institution, DOT, recommendations, section and project discussions (the latter in `Oli.Authoring.Audited`), notes, `apply_major_updates`, LTI service fields.
3. **C — Assessment settings and exceptions.** `Oli.Delivery.Settings.Audited` with the Boundary check; single and bulk commands, exceptions, history writers removed from the application paths.
4. **D — History conversion.** Migration, migration test, rehearsal, readers removed, runbook Preflight step.
5. **E — Remix and publication updates.** `save_remix`, `apply_publication_update`, job context, publish and manage callers, Scenarios.
6. **F — Gating and scheduling.** `Oli.Delivery.Gating.Audited` with the Boundary check; gate commands, schedule update and clear, Scenario and seeders.
7. **G — Final verification.** Format; `mix compile --warnings-as-errors` in dev, test, and playwright; affected and full suites with the leak check; latency evidence; `harness-review` (security, performance, Elixir, UI); work-item validation; event reference regenerated; caller inventory closed against the diff.

No commit, push, PR, Jira change, or change to `handoff.md` is part of this design. PR-05's draft base is `sub-task/MER-6114-audit-log-coverage-authoring-projects-imports-and-repairs`, opened with the caution block naming #7054.
