# PR-04 Coverage: Authoring, Projects, Imports, and Repairs - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- FDD: `docs/exec-plans/current/features/audit-log-expansion/fdd.md` (section 7.4 for import and repair outcomes)
- Plan: `docs/exec-plans/current/features/audit-log-expansion/plan.md` (Phase 4, MER-6114)
- Scope: `docs/exec-plans/current/features/audit-log-expansion/jira-subtasks.md` (PR-04)
- Inventory: `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md` (W09, W10, W11, W19, W20)
- Predecessors: `docs/exec-plans/current/features/audit-log-expansion/design/pr-02-boundary-and-ci-with-audited-user-deletion-pilot.md`, `docs/exec-plans/current/features/audit-log-expansion/design/pr-03-identity-and-platform-administration.md`

Status: approved by the owner on 2026-11-13. Source inspected at `456d235388` (last PR-03 commit). No code, migration, or database command has run for this design; one temporary test confirmed the media authorization gap in section 7 and was deleted. Implementation evidence belongs in `phase-4-execution.md`, which starts at checkpoint A after approval.

## 1. Slice Summary

Make every supported authoring write that MER-6066 names an audited command: project lifecycle, publishing, collaborators, project settings, destructive content and media changes, authoring configuration, project- and content-level DOT and activation points, and the imports, repairs, and administrative replacements that rewrite authored content. Each command writes the change and its events in one transaction, through an audited facade that is separate from the domain code it calls (PR-02 pattern). Move the two existing producers this PR owns, `project_published` and `google_doc_imported`, into those transactions and off the legacy adapter.

In scope (internal blocks, implemented in this order):

1. **Project lifecycle, publishing, and collaborators (W09).** Create, duplicate, delete, publish; collaborator invitation, acceptance, rejection, and removal; the restriction of `Course.update_project/2`.
2. **Project settings and project DOT (W19).** Overview settings, visibility and duplication, sharing grants, customizations, payment-code transfer, auto-update, learning model, coverage thresholds, required survey, activity and tool availability, experiments, alternatives, and the project trigger switch.
3. **Destructive content and media (W10).** Page and container removal, activities removed from pages (explicitly or by a page edit), activity and bank-question deletion, media deletion, objective, alternatives-group, and bibliography deletion.
4. **Authoring configuration and content DOT (W20).** Page and assessment options, bank selection rules, learning objectives and their attachments, curriculum moves and reordering, content-level `ai_enabled`, and trigger prompts.
5. **Imports, repairs, and replacements (W11).** Archive ingest, Google Doc import, project repair, revision-history restore and JSON or attribute edits, course-metadata CSV import, and learning-model parameter CSV import.

Out of scope:
- Ordinary content editing (text and media in a page or activity) that neither removes content nor changes configuration. Content creation (new pages, activities, duplicates) is not audited.
- Section-level DOT, triggers, and instructor recommendations (PR-05, extending the policy in section 4.4). Products created by an archive import are part of `project_imported`; product lifecycle elsewhere is PR-05.
- Authorization fixes: TRIAGE-2569 (admin live navigation) and TRIAGE-2622 (media API without project access check). Section 7 records both as residual risks.
- Runtime trigger invocation (`trigger_point_controller.ex`), experiment assignment at delivery, and learner data.
- New product behavior and new endpoints.

## 2. Requirements Coverage

These are design mappings, not implementation proof. `requirements.yml` gains no evidence entries until real evidence exists. Code and tests carry no requirement or ticket codes.

| Requirement / criteria | This slice's responsibility and planned proof |
| --- | --- |
| FR-005 / AC-018 | Ingest, Google Doc import, and repair build the `Context` in the LiveView from the authenticated author and pass it into the task; events carry that author, never a worker identity |
| FR-008 / AC-025 | `project_created`, `project_duplicated` (source ref), `project_imported`, `project_deleted`; the initial owner as affected author; title snapshot survives later renames or deletion |
| FR-008 / AC-026 | `project_published` written inside the publication transaction, only after the publication commits; working-publication bookkeeping (initial setup, new working publication, unique-ID marking) writes nothing |
| FR-008 / AC-027 | `project_collaborator_changed` for invitation, acceptance, rejection, and removal, with the collaborator as affected author and `status`/`role` before and after. Ownership is set only at creation (section 3.4) |
| FR-011 / AC-033 | Project `allow_triggers` and content `ai_enabled` diffs; trigger prompts extracted from page and activity content, with prompt text before and after (section 4.4) |
| FR-011 / AC-034 | Not this PR: instructor recommendations are section-level (PR-05) |
| FR-013 / AC-037 | `authoring_content_removed`, `bank_question_deleted`, `media_deleted` with resource, revision, and media identity and title snapshots, including activities removed by a page edit |
| FR-013 / AC-038 | `authoring_content_replaced` per committed page of a repair and per replaced revision of a history or CSV replacement; nothing for rolled-back work |
| FR-016 / AC-043, AC-044 | `project_settings_changed` for every persisted project setting (section 3.3), including grants, activity availability, experiments, and alternatives; `update_project/2` closed to them |
| FR-017 / AC-045, AC-046 | `authoring_settings_changed` (page options, bank selection rules), `learning_objectives_changed` (objective edits, deletions, attachments), `curriculum_changed` (moves, reorders) |
| FR-027 / AC-066 | Ingest, Google Doc import, repair, history replacements, and both CSV imports, each recorded in the transaction that commits it (FDD 7.4) |
| FR-029 / AC-069 | `project_published` and `google_doc_imported` keep their names and details; the legacy adapter keeps only `section_created`, `resource_attempt_deleted`, and `clickhouse_admin_operation_initiated` |
| FR-030 | Google Doc file IDs only as the existing hash; no source URLs, file contents, or credentials in events |
| FR-035 / AC-092 | Facades add no authorization; checks that live in migrated functions (repair's system-admin check, collaborator owner protection, lock checks) move inside the transaction |
| FR-036 | New facades as independent Boundaries with private implementation modules (section 3.1) |
| FR-037 / AC-097 | Scenario directives for projects, publication, collaborators, objectives, banks, and pages use the represented author; bootstrap and seeding use `playwright_setup` |

### 2.1 Caller and write inventory

Gathered at `456d235388` from the callers, changesets, direct `Repo` writes, and route pipelines of each function. Line numbers are indicative. Every checkpoint re-verifies its rows against the diff and records the final mapping in `phase-4-execution.md`. **M** = migrated to an audited command; **C** = composed inside another audited command; **X** = excluded, with the reason.

#### Project lifecycle, publishing, and collaborators

| Current path | Today | Class |
| --- | --- | --- |
| `Course.create_project/3` (`course.ex:1092`) via `project_controller.ex:23` | One transaction (family, project, owner, root container, initial working publication); no audit | M: `create_project/3` |
| `Clone.clone_project/3` (`clone.ex:18`) via `project_controller.ex:37`, `cognito_controller.ex:200`, `torus_doc.ex:91`, Scenario `clone_handler.ex:20` | One transaction including bulk SQL copies | M: `duplicate_project/3` |
| `Course.create_project_from_archive/4` (`course.ex:1102`) inside the ingest transaction | Nested savepoint | C: inside `ingest_archive` (block 5) |
| `Course.create_project/1` (`course.ex:1067`), only from Scenario `section_handler.ex:165` | Bare insert without family | M: the Scenario uses `create_project/3` |
| `update_project(project, %{status: :deleted})` (`overview_live.ex:935`) | Single update | M: `delete_project/2` |
| `Publishing.publish_project/3` (`publishing.ex:1018`) via `publish_live.ex:192`, `publish_view.ex:226`, ingest `products.ex:22,96`, `automation_setup.ex:251`, Scenarios (`publish_handler`, `section_handler`, `remix_handler`, `product_handler`), seeders | Lock transaction, then publication transaction; `project_published` captured after commit, result ignored (`publishing.ex:1101`) | M: `Publishing.Audited.publish_project/3`; event inside the publication transaction |
| `initial_publication_setup`, `create_publication` for the new working publication, `UniqueIds.add_unique_ids` | Publication bookkeeping | C: no event |
| `Collaborators.invite_collaborator/5` via `collaborator_controller.ex:155` | Author invite (audited in PR-03), then `AuthorProject` insert, token insert, email: separate steps | M: `invite_collaborator_multi/4`, composed with `Accounts.Audited.invite_author_multi/4`; email after commit |
| `Collaborators.remove_collaborator/2` inside the controller Multi (`collaborator_controller.ex:139`) | Delete; owner protected | C: `remove_collaborator_multi/4` |
| `Course.update_author_project/2` via `invite_view.ex:200,215,289`, `author_authorization_controller.ex:342` | Status update | M: `respond_to_invitation/3` |
| `Accounts.accept_collaborator_invitation*/3` (`accounts.ex:1444`, `:1497`) | Multi with the PR-03 account step | C: collaborator step and event added to the Multi |
| `Collaborators.add_collaborator/2` via `do_create_project`, `clone.ex:47`, Scenario `collaborator_handler.ex:42` | Insert; first author becomes owner | C at creation; M: Scenario uses `add_collaborator/3` |
| `CollaboratorController.update/2` (PUT stub) | Empty body; returns no conn | X: writes nothing |
| `authors_projects` cascade on author deletion | Database cascade | X: covered by `author_deleted` |
| Seeders (`db_seeder.ex`, `seeder/project.ex`) direct `AuthorProject` inserts | Test and development setup | X: direct inserts stay; their `publish_project` calls use the facade with `playwright_setup` |

#### Project settings and project DOT

| Current path | Fields | Class |
| --- | --- | --- |
| `overview_live.ex:915` `"update"` via `update_project/2` | Form fields: title, description, welcome title, subtitle, publisher, ECL flag, attributes (language, embeddings, license); raw params reach the changeset | M: `update_project_settings/4` with the form's field allowlist; any other key returns `:protected` |
| `overview_live.ex:1149` | `experiments_enabled`, `alternatives_enabled` | M |
| `visibility.ex:350`, `:356` | `visibility`, `allow_duplication` | M |
| `Publishing.insert_visibility/1`, `remove_visibility/1` via `visibility.ex:375,403,448` | `project_visibilities` rows, one write each in a loop | M: `update_visibility_grants/3`, one transaction (pseudo key `visibility_grants`) |
| `customization.ex:50`, `transfer_payment_codes.ex:33` | `customizations`, `allow_transfer_payment_codes` | M |
| `publish_live.ex:169`, `publish_view.ex:201` (`"form_changed"`) | `auto_update_sections`, written on every form change | M: no event when unchanged |
| `project_controller.ex:53` `enable_triggers` | `allow_triggers: true` | M: `activation_settings_changed` (project scope) |
| `Course.update_project_attributes/2` via `objectives_live.ex:1569` | Coverage thresholds | M |
| `Course.upgrade_learning_model/2` via `overview_live.ex:870` | Project and blueprint `learning_model_version` | M: event inside the existing transaction; blueprint count in details |
| `Course.create_project_survey/2`, `delete_project_survey/2` via `required_survey.ex:79,81` | Survey page plus `required_survey_resource_id`; no transaction | M: one transaction each |
| `Activities.bulk_update_project_activities/…` (`activities.ex:543`) via `add_activities_and_tools_modal.ex:136`; `enable_activity_in_project`, `disable_activity_in_project` via `advanced_activity_item.ex:46,70` | `activity_registration_projects`, including LTI tools | M: `Activities.Audited` (pseudo key `enabled_activities`) |
| `Experiments` create, update, condition availability, status transitions (`experiments.ex:63-336`) via `experiments_live.ex`, `experiment_details_live.ex` | Experiment definitions and conditions | M: `Experiments.Audited`; `update_section_participation` is section-level and left to PR-05 |
| Alternatives groups through `ResourceEditor.create/edit` and `AlternativesOptionEditor` via `alternatives_live.ex` | Alternatives revisions | M (pseudo key `alternatives_groups`); deletion in block 3 |
| `update_project_latest_*` (`course.ex:1259-1283`) via `ProjectExportWorker` | Export and snapshot URLs | X: system-maintained; stays on the restricted `update_project/2` |
| `Activities.set_global_status/visibility` | Global registration | X: platform administration, not a project setting |
| Ingest `hierarchy.ex:61`, `common.ex:36`; clone copies | Settings set at creation | C: part of import or duplication; the ingest writes its late labels and survey link through `complete_import/3` |

#### Destructive content and media

| Current path | Today | Class |
| --- | --- | --- |
| `ContainerEditor.remove_child/4` (`container_editor.ex:327`) via `curriculum_live.ex:450`, `pages_live.ex:199`, `container_live.ex:407`, `pages_view.ex:415` | Transaction, page lock, deleted page revision cascading to embedded activities, container revision | M: `remove_from_curriculum/4`; one event for the page or container, listing cascaded activity IDs |
| Unattached page delete copied in four LiveViews (`curriculum_live.ex:429`, `pages_live.ex:174`, `container_live.ex:386`, `pages_view.ex:390`) | `track_revision(deleted: true)` without lock check or cascade | M: `delete_unattached_page/3`; keeps today's behavior (no new lock check or cascade) |
| `PageEditor.edit/4` (`page_editor.ex:64`) via `resource_controller.ex:101`, `editor_live.ex:481,878` | Transaction and lock; cascades removed activity references (`page_editor.ex:628`) | M: `edit_page/5` (block 4); removed references produce `authoring_content_removed` |
| `ActivityEditor.delete/4`, `delete_bulk/3` via `activity_controller.ex:753,778` | Transaction and lock | M: `bank_question_deleted` for bank activities, `authoring_content_removed` otherwise; one event per activity |
| `ActivityBank.delete/…`, `delete_bulk/…` (`activity_bank.ex:218,228`) and Scenario `activity_bank_handler.ex:123` | Delegates to `ActivityEditor` | C: the Scenario checks the banked scope and calls `delete_activity/5`; `ActivityBank` has no other product caller |
| `MediaLibrary.delete_media_items/2` (`media_library.ex:91`) via `media_controller.ex:288` | `update_all deleted: true` by media ID only; S3 untouched | M: `delete_media/3`; one event per row with the row's own `project_id` (section 7) |
| `MediaLibrary.restore_item/1` inside `MediaLibrary.add/3` on duplicate upload | Undelete as upload deduplication | X: side effect of an upload, not a restoration action |
| `ObjectiveEditor.delete/…` (`objective_editor.ex:193`) via `objectives_live.ex:1288`, `objectives.ex:452`; `delete_sub_objective` (`:311`) | Transaction; detachment from pages runs first in separate transactions | M in block 4 with the other objective writers (owner decision 2026-11-16): `learning_objectives_changed`; detachments are their own page and activity edits |
| `ResourceEditor.delete/…` via `alternatives_live.ex:318`, `experiments_live.ex:815` | `track_revision(deleted: true)`, no transaction | M: `authoring_content_removed` |
| `BibEntryEditor.delete/…` via `bib_entry_controller.ex:107` | Transaction | M: `authoring_content_removed` |
| `Course.delete_project_survey/2` | Survey page deletion | C: inside the survey command |
| Scenario `ops.ex:285`, `edit_page_handler.ex:182`, `edit_adaptive_page_handler.ex:115`, `hooks.ex:78`; `DbSeeder.delete_page` | Direct revision writes for test setup | X: test harness writes that bypass editors on purpose |

#### Authoring configuration and content DOT

| Current path | Class |
| --- | --- |
| `ContainerEditor.edit_page/3` (`container_editor.ex:56`) via `container_live_helpers.ex:85` (curriculum, pages, container, pages view) and Scenario `ops.ex:338`, `builder.ex:104` | M: `update_page_options/4` (`authoring_settings_changed`, `dot_settings_changed` for `ai_enabled`) |
| `PageEditor.edit/4` saves from the React editors and `editor_live.ex` | M: `edit_page/5` diffs configuration fields, selection rules, objectives, and triggers against the locked before-state; ordinary content changes emit nothing |
| `ActivityEditor.edit/…`, `bulk_edit/…` via `activity_controller.ex:603,665`, `activity_bank.ex:86`, `authoring_launch.ex:161` | M: `edit_activity/6` and `edit_activities/5` (bulk) diff `objectives` and triggers per activity |
| `ObjectiveEditor` add, edit, parent and sub-objective operations, detach (`objective_editor.ex:22-398`) via `objectives_live.ex`, `objectives.ex`, `objectives_controller.ex:155,227`, `resource_controller.ex:127`, Scenario `objectives_handler.ex` | M: `learning_objectives_changed` per objective whose title, sub-objectives, or deleted flag changed (entity `:objective`); detachments record on each page and activity they edit. `resource_controller.ex` `create_objective` has no route and is migrated with the rest |
| `ContainerEditor.move_to/…`, `reorder_child/…` via the curriculum LiveViews and Scenario `ops.ex:153,245` | M: `curriculum_changed` |
| `ContainerEditor.add_new/4`, `duplicate_page/…`, `ActivityEditor.create*`, MCP `create_activity_tool.ex:125` | X: creation is not audited; `add_new` stays public and is composed by the Google Doc import |
| `Collaboration.upsert_collaborative_space` | X here: discussion configuration (PR-05) |
| Child deduplication on mount (`curriculum_live.ex:1160`, `container_live.ex:156`) | X: automatic structural repair on read |

#### Imports, repairs, and replacements

| Current path | Today | Class |
| --- | --- | --- |
| `Ingest.Processor.process/1` via `ingestv2.ex:238` (`Task.async`); `Ingest.ingest/2` via `automation_setup.ex:264` | One outer transaction (`processor.ex:30`) | M: `Interop.Audited.ingest_archive/3`; `project_imported` plus the nested `project_published` events in that transaction |
| `GoogleDocs.Import.import/5` via `curriculum_live.ex:241` (`Task.Supervisor.async_nolink`) | Media and activities commit first; page created in `ContainerEditor.add_new` (`container_editor.ex:125`); event after commit (`import.ex:976`) | M: page creation and `google_doc_imported` in one transaction through `Authoring.Audited.import_google_doc_page/5` |
| `ProjectRepair.repair_project/3` via `project_repair_live.ex:532` (`start_async`) | Lock transaction, one transaction per page (`repair.ex:435`), `RepairResult` | M: `repair_project/3`; one `authoring_content_replaced` per committed page |
| `history_live.ex:102,168,227` and `revision_history.ex:207,284,416` (`mimic_edit`, JSON save, attribute edit) | Force-clears the lock, new revision or in-place update, no transaction | M: `restore_revision/4`, `replace_revision_content/4`, `update_revision_attribute/5` |
| `CSVImportView` (`csv_import_view.ex:155`) | In-place `update_revision` per row in a task | M: `import_metadata_row/4`, one transaction and event per row; partial by design, as today |
| `ParameterCsv.import/3` (`parameter_csv.ex:95`) via `learning_model_parameters_live.ex:134` | One transaction | M: `import_learning_parameters/3`, one event per changed revision |
| `CustomActivities.Package.import` | S3 uploads only, no database write | X |
| `Oli.Release.reset/drop`, dashboard UI resets | Tooling or UI state | X |

## 3. Responsibilities & Boundaries

### 3.1 Facades and Boundary topology

| Facade | Covers |
| --- | --- |
| `Oli.Authoring.Audited` (new) | Projects, collaborators, project settings, destructive content and media, authoring configuration, Google Doc page import, repair, history and CSV replacements |
| `Oli.Publishing.Audited` (new) | Publication and sharing grants |
| `Oli.Activities.Audited` (new) | Activity and tool availability in a project |
| `Oli.Experiments.Audited` (new) | Experiment definitions and their lifecycle |
| `Oli.Interop.Audited` (extended) | Archive ingest, next to the existing API key commands |

Each new facade declares `use Boundary, top_level?: true, exports: [], check: [out: false]` and is added to `deps` in `lib/oli.ex`, `lib/oli_web.ex`, `lib/oli/constellation.ex`, and `test/support/live_component_tests.ex`.

**Editors (owner decision 2026-11-13, option A).** The write functions of the editors move into private modules of `Oli.Authoring.Audited`, so the Boundary blocks any caller that skips the facade. Reads, lock management, and context builders stay public where they are:

| Module | Moves into the facade | Stays public |
| --- | --- | --- |
| `PageEditor` | `edit/4` and its private helpers | `create_context`, `acquire_lock`, `release_lock`, reads |
| `ContainerEditor` | `remove_child` (block 3); `move_to`, `reorder_child`, `edit_page` (block 4) | `add_new`, `duplicate_page`, reads |
| `ActivityEditor` | `edit`, `bulk_edit`, `delete`, `delete_bulk` and their helpers (block 4: the deletes share the revision writer with the edits; block 3 audits them through the facade) | `create*`, reads, bundle repair, and `validate_request/1`, which creation shares |
| `ActivityBank` | nothing: `update`, `delete`, and `delete_bulk` keep their bank checks and reference resolution, take a `Context`, and call the facade, so no write path bypasses it | reads, `create` |
| `ObjectiveEditor` | every writer (block 4); `add_new_parent_for_objective/4`, which had no caller, is removed | reads, the detachment preview, and the association checks the reads share |
| `ResourceEditor`, `BibEntryEditor` | `delete` | reads, `create`, `edit`, `get_or_create_tag`: creating and editing tags, bibliography entries, and other resources is ordinary content editing (owner decision 2026-11-16) |
| `MediaLibrary` | `delete_media_items`, `delete_items` | reads, uploads |
| `Course` | `create_project/3`, `create_project_from_archive/4`, `delete`, settings writers, survey writers, `upgrade_learning_model`, `update_author_project` | reads; `update_project/2` restricted (section 3.3) |
| `Clone`, `Collaborators` | writers | reads, email helpers |
| `ProjectRepair.Repair`, `ParameterCsv` writes | the module, renamed under the facade | `ProjectRepair.analyze_project` |

`Publishing.publish_project/3`, `insert_visibility`, and `remove_visibility` move into `Oli.Publishing.Audited`; `Activities` and `Experiments` writers move into their facades; `Ingest.ingest/2` and `Processor.process/1` move into `Oli.Interop.Audited`. Processor step modules stay where they are: they only run inside that transaction. The moves are mechanical (rename and update callers); behavior changes are limited to those listed in section 5.

Generic low-level writers (`Resources.create_revision_from_previous`, `Resources.update_revision`, `ChangeTracker.track_revision`) stay public: dozens of non-audited paths need them. The caller inventory, not the Boundary, closes their audited uses (section 7).

At checkpoint A, verify the topology with a temporary forbidden reference per new facade, as in PR-03, recorded and not committed.

### 3.2 Responsibilities

- **Facade:** owns the transaction (or composes into the caller's), locks, the before-state read, the diff, event construction, and safe errors. Adds no authorization; moves into the transaction any check that already lived in the migrated function.
- **Private implementation modules:** the moved editor and domain writes, unchanged except for taking the transaction from the facade. In `Oli.Authoring.Audited`, the public module holds each command's documentation, spec, argument guards, and `:invalid_request` fallback; one private module per area (`Projects`, `Settings`, `Alternatives`, `Content`, `Collaborators`, `Pages`, `Activities`, `Objectives`, `Curriculum`, and later `Repair`) holds the command bodies, their event construction, and the writes they run, with event recording shared in `Support`. Each module's header names the editor each moved write came from (owner decision 2026-11-17).
- **Domain modules:** reads, locks, creation paths, and unaudited system writes.
- **Transport (LiveViews, controllers, tasks):** builds the `Context`, calls the facade, and runs broadcasts, lock release, cache invalidation, emails, and redirects after commit. Every LiveView that now calls a facade handles non-changeset errors with a flash instead of `{:ok, _} =` matches.

### 3.3 Project protected-key map

`Course.update_project/2` stays public only for the system-maintained export and snapshot fields (`latest_export_url`, `latest_export_timestamp`, `latest_analytics_snapshot_url`, `latest_analytics_snapshot_timestamp`, `latest_datashop_snapshot_url`, `latest_datashop_snapshot_timestamp`). Any other key returns `:protected`, following `Oli.Accounts.ProtectedKeys`.

| Fields | Event |
| --- | --- |
| `status` (to `:deleted`) | `project_deleted` |
| `allow_triggers` | `activation_settings_changed` (project scope) |
| Every other `Fields.project_settings()` field, `attributes` subfields, and the pseudo keys `visibility_grants`, `enabled_activities`, `alternatives_groups`, `experiment_status`, `experiment_conditions`, `experiment_definition` | `project_settings_changed` |
| `slug`, `version`, `family_id`, `project_id`, `legacy_svn_root`, `lo_well_formed`, timestamps | Not writable after creation through any command; already excluded in `Fields` |

`analytics_version` stays in the policy as declared by PR-01; no current UI writes it.

### 3.4 Ownership

Ownership is assigned once: `Collaborators.change_collaborator` gives the owner role to the first author added, which is the creator of a new, duplicated, or imported project. Nothing changes `project_role_id` afterwards, the owner cannot be removed, and the collaborator PUT route is an empty stub. The creation events carry that owner as the affected author. `project_ownership_changed` is removed from the catalog (owner decision 2026-11-13): it was never emitted and the story has not reached production, so no stored row uses it. If a transfer feature is ever built, it adds its event then.

## 4. Interfaces & Signatures

Commands follow the PR-02 shape: a `*_multi/4` builder for callers that compose, and a wrapper that owns the transaction and returns `{:error, :nested_transaction}` inside one. Function-style transactions (publication, ingest, editors) append with `Auditing.build/2` and `Auditing.insert/1`, rolling back on error.

```elixir
@type command_error ::
        :invalid_request | :not_found | :nested_transaction | :protected | :locked
        | Ecto.Changeset.t() | Oli.Auditing.Error.t() | term()
```

`term()` covers the existing domain error tuples that callers already render (lock messages, editor errors); they are returned unchanged.

### 4.1 Projects, publishing, collaborators

```elixir
# Oli.Authoring.Audited
@spec create_project(Context.t(), String.t(), Author.t(), keyword()) :: {:ok, map()} | {:error, command_error()}
@spec duplicate_project(Context.t(), String.t(), Author.t(), keyword()) :: {:ok, Project.t()} | {:error, command_error()}
@spec delete_project(Context.t(), pos_integer()) :: {:ok, Project.t()} | {:error, command_error()}
@spec invite_collaborator_multi(Multi.t(), Multi.name(), Context.t(), {Project.t(), String.t()}) :: Multi.t()
@spec respond_to_invitation(Context.t(), {pos_integer(), pos_integer()}, :accepted | :rejected) :: {:ok, AuthorProject.t()} | {:error, command_error()}
@spec remove_collaborator_multi(Multi.t(), Multi.name(), Context.t(), {Project.t(), Author.t()}) :: Multi.t()
@spec add_collaborator(Context.t(), Author.t(), Project.t()) :: {:ok, AuthorProject.t()} | {:error, command_error()}

# Oli.Publishing.Audited
@spec publish_project(Context.t(), Project.t(), String.t() | nil, pos_integer()) :: {:ok, Publication.t()} | {:error, command_error()}
@spec update_visibility_grants(Context.t(), pos_integer(), %{add: [grant], remove: [grant]}) :: {:ok, [ProjectVisibility.t()]} | {:error, command_error()}
```

- `publish_project` keeps both transactions. The event is appended inside the second one, after `update_publication(published: now)`, with the current details (`project_title`, `publication_id`, `description`, `version`) and `previous`/`resulting` publication refs. The last argument is the author who owns the editing locks, usually the actor of the `Context`.
- Inside the ingest transaction, the nested publications record their own `project_published` events: they are real publications.
- `project_collaborator_changed` uses `status` and `role` changes: invitation `nil → pending_confirmation`, acceptance `pending_confirmation → accepted`, rejection to `rejected`, removal `accepted → nil`. The owner protection of `remove_collaborator` stays inside the transaction.
- Collaborator invitation is atomic for the database writes (account invitation, `AuthorProject`, token); the email is sent after commit. A failed email keeps today's behavior.

### 4.2 Project settings

```elixir
@spec update_project_settings(Context.t(), pos_integer(), map(), [atom()]) :: {:ok, Project.t()} | {:error, command_error()}
@spec enable_triggers(Context.t(), pos_integer()) :: {:ok, Project.t()} | {:error, command_error()}
@spec upgrade_learning_model(Context.t(), pos_integer()) :: {:ok, Project.t()} | {:error, command_error()}
@spec create_project_survey(Context.t(), pos_integer()) :: {:ok, Project.t()} | {:error, command_error()}
@spec delete_project_survey(Context.t(), pos_integer()) :: {:ok, Project.t()} | {:error, command_error()}
@spec complete_import(Context.t(), Project.t(), map()) :: {:ok, Project.t()} | {:error, command_error()}
@spec create_alternatives_group(Context.t(), String.t(), Author.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec edit_alternatives_group(Context.t(), String.t(), pos_integer(), Author.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec move_alternatives_option(Context.t(), String.t(), Author.t(), [map()], term(), String.t(), term()) :: {:ok, [map()], map()} | {:ok, :unchanged} | {:error, command_error()}

# Oli.Activities.Audited
@spec update_project_activities(Context.t(), pos_integer(), %{add: [pos_integer()], remove: [pos_integer()]}) :: :ok | {:error, command_error()}
@spec set_project_activity_status(Context.t(), pos_integer(), pos_integer(), :enabled | :disabled) :: :ok | {:error, command_error()}

# Oli.Experiments.Audited
@spec create_experiment(Context.t(), CreateExperimentRequest.t()) :: {:ok, term()} | {:error, command_error()}
@spec update_experiment(Context.t(), pos_integer(), UpdateExperimentRequest.t()) :: {:ok, term()} | {:error, command_error()}
@spec update_condition_availabilities(Context.t(), pos_integer(), [map()], Scope.t()) :: {:ok, term()} | {:error, command_error()}
@spec transition_experiment(Context.t(), pos_integer(), :activate | :pause | :complete | :archive, LifecycleRequest.t()) :: {:ok, term()} | {:error, command_error()}
@spec update_condition_availability(Context.t(), pos_integer(), pos_integer(), boolean(), Scope.t()) :: {:ok, term()} | {:error, command_error()}
@spec update_section_participation(Context.t(), pos_integer(), Scope.t(), [pos_integer()]) :: {:ok, term()} | {:error, command_error()}
@spec remove_condition(Context.t(), pos_integer(), pos_integer(), Scope.t()) :: {:ok, term()} | {:error, command_error()}
@spec remove_intervention(Context.t(), pos_integer(), pos_integer(), Scope.t()) :: {:ok, term()} | {:error, command_error()}
@spec remove_assessment_binding(Context.t(), pos_integer(), pos_integer(), Scope.t()) :: {:ok, term()} | {:error, command_error()}
```

- `update_project_settings` takes the caller's field allowlist (the overview form, the visibility component, customizations, and so on). Keys outside it return `:protected`. Attributes are diffed field by field against the persisted embed, since the changeset replaces the whole embed.
- `auto_update_sections` writes and emits only when the value changes.
- The learning-model upgrade records the project change with the number of updated blueprints in details; blueprint section events belong to PR-05.
- `complete_import/3` writes only `customizations` and `required_survey_resource_id`, which an archive defines after the project exists, and only inside the import that recorded `project_imported` for that project under the same context (`operation_id`); `project_imported` covers them, so it records no event. The import's creation runs as a savepoint, so the check uses the operation, not the transaction ID.
- Experiments record `experiment_status`, `experiment_conditions`, and `experiment_definition`, with `experiment_id` in details. `experiment_definition` holds every other definition setting, the interventions with their assessment bindings, and the participating sections. Values are compared by IDs, without row IDs or timestamps; recorded values add page, alternatives, and section titles. The before state is read after locking the definition, in the same transaction. The experiment configuration writers, with the persistence and lifecycle modules they use, move into the private `Oli.Experiments.Audited.Writes`, `Oli.Experiments.Audited.ConfigurationPersistence`, and `Oli.Experiments.Audited.Lifecycle`, so the Boundary blocks any caller that skips the facade. The validation and read helpers they share with the queries move to the internal `Oli.Experiments.Support`; none of them writes configuration. Runtime writes (assignments, exposures, rewards) are delivery activity, not configuration, and stay in `Oli.Experiments`.
- Alternatives groups are recorded as `alternatives_groups` (`added` on creation, `set` on edits) with resource ID, title, strategy, and options, and `alternatives_group_id` in details. `ResourceEditor.create` and `edit` and `AlternativesOptionEditor` stay public as generic resource writers (owner decision 2026-11-16); the final caller inventory checks that only the facade uses them for alternatives groups.

### 4.3 Destructive content and media

```elixir
@spec remove_from_curriculum(Context.t(), Revision.t(), Project.t(), Author.t(), String.t()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec delete_unattached_page(Context.t(), Project.t(), String.t()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec delete_activity(Context.t(), String.t(), term(), term(), Author.t()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec delete_activities(Context.t(), String.t(), [term()], Author.t()) :: {:ok, term()} | {:error, command_error()}
@spec delete_alternatives_group(Context.t(), String.t(), pos_integer(), Author.t()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec delete_bib_entry(Context.t(), String.t(), term(), Author.t()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec delete_media(Context.t(), String.t(), [term()]) :: {:ok, non_neg_integer()} | {:error, command_error()}
```

- Events reference the resource, the deleted revision, and the previous revision; `changes` record `deleted: false → true`, and the entity snapshot keeps the title; details list cascaded `removed_activity_ids`. Each command locks the working-publication mappings of its resources (`FOR UPDATE`) before reading the before-state. Content that was already deleted, or that the write did not delete, records nothing. The commands keep each caller's results and errors; the curriculum broadcast runs after commit.
- Bank questions (activities with the banked scope) record `bank_question_deleted`; embedded activities `authoring_content_removed`. Bulk deletion emits one event per activity, sharing the operation ID, inside the existing all-or-nothing transaction.
- `delete_media` keeps today's query and response. It selects the rows with `FOR UPDATE` before the update and records one `media_deleted` per row that actually changed, using each row's own `project_id`, `file_name`, and `mime_type`. Already-deleted rows emit nothing.
- When an activity delete updates the working revision in place (lock result `:updated`), the previous and resulting references carry the same revision ID, with the before-state taken under the lock.
- Alternatives groups and bibliography entries record `authoring_content_removed`, as section 2.1 lists; their creation and edits are not removal.

### 4.4 Authoring configuration and the DOT field policy

```elixir
@spec edit_page(Context.t(), String.t(), String.t(), String.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec edit_activity(Context.t(), String.t(), term(), term(), String.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec edit_activities(Context.t(), String.t(), term(), String.t(), [map()]) :: {:ok, [Revision.t()]} | {:error, command_error()}
@spec update_page_options(Context.t(), Project.t(), String.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec move_curriculum_entry(Context.t(), Project.t(), map()) :: {:ok, term()} | {:error, command_error()}
# create_objective/5, link_sub_objective/5, edit_objective/5, delete_objective/5,
# unlink_sub_objective/5, delete_sub_objective/5, detach_objective/4: the editor's arguments
# after a Context, returning the editor's results
```

A content save produces events only for what changed between the locked before-state and the result:

| Change detected | Event | Data |
| --- | --- | --- |
| Activity references removed (`Utils.diff_activity_references/2`) | `authoring_content_removed` | One event per removed activity, with its previous and resulting revisions; a save that deletes the page records the page instead, with `removed_activity_ids` |
| `Fields.authoring_configuration()` fields | `authoring_settings_changed` | Field diff |
| Bank selection rules (`selection` elements: ID, count, logic) | `authoring_settings_changed` | Pseudo key `selection_rules` |
| `objectives` | `learning_objectives_changed` | Attached and detached objective IDs |
| `ai_enabled` | `dot_settings_changed` | Field diff |
| Triggers | `activation_settings_changed` | Pseudo key `triggers` |

**Trigger projection (the DOT interface PR-05 extends).** `Oli.Auditing.DotPolicy.triggers(content)` returns a list of `%{"path" => location, "trigger_type" => type, "prompt" => text}` for page triggers, group and content-block triggers, activity part triggers, adaptive `janus-ai-trigger` parts, and `activationPoint` rule actions. Prompts are recorded up to 2,000 characters, with `"prompt_truncated" => true` when cut (owner decision 2026-11-13). The diff compares the lists by `path` and records only the triggers added, removed, or changed. Paths: `page`, `group:<id>`, `content:<id>`, `part:<part id>:<trigger id>`, `part:<part id>` for adaptive trigger parts, and `rule:<rule>:<index>` for activation points. Bank selections are compared the same way, by selection ID, under `selection_rules`. Restoring a removed activity reference (undo) restores the activity without an event. PR-05 reuses `DotPolicy` and `Fields.dot_activation()` for section and recommendation settings; it adds keys to that policy instead of defining a second one. The interface is documented in the module and in `plan.md` phase 5 at checkpoint D.

In-lock saves that update the same working revision in place still diff against the before-state read under the lock, so autosaves with no configuration change emit nothing. Curriculum moves record `children` before and after for each affected container; a move between containers emits one event per container.

### 4.5 Imports, repairs, and replacements

```elixir
# Oli.Interop.Audited
@spec ingest_archive(Context.t(), Oli.Interop.Ingest.State.t(), keyword()) :: {:ok, Project.t()} | {:error, term()}

# Oli.Authoring.Audited
@spec import_google_doc_page(Context.t(), Project.t(), Revision.t(), map(), (Revision.t() -> map())) :: {:ok, Revision.t()} | {:error, command_error()}
@spec repair_project(Context.t(), Project.t() | String.t(), keyword()) :: {:ok, RepairResult.t()} | {:error, term()}
@spec restore_revision(Context.t(), Project.t(), pos_integer(), pos_integer()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec replace_revision_content(Context.t(), Project.t(), pos_integer(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec update_revision_attribute(Context.t(), Project.t(), pos_integer(), atom(), term()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec import_metadata_row(Context.t(), Project.t(), map()) :: {:ok, Revision.t()} | {:error, command_error()}
@spec import_learning_parameters(Context.t(), Project.t(), binary()) :: {:ok, map()} | {:error, term()}
```

Following FDD 7.4, each records inside the transaction that commits its work and records nothing for rolled-back work:

- **Ingest:** `project_imported` when the project is created inside the outer transaction, with the importing author as actor and owner. A failed ingest rolls back the project, its events, and the nested publication events.
- **Google Doc import:** the facade wraps `ContainerEditor.add_new/4` and appends `google_doc_imported` in its transaction, with the current detail keys. Media and activities committed before the page stay outside it, as today; the media counts remain details of the committed event. A page failure records nothing.
- **Repair:** the facade injects a per-page step into the repair loop; each committed page transaction appends one `authoring_content_replaced` (page, previous and resulting revision, remapped activity count, `reason: repair`). `RepairResult` keeps its statuses; `:failed` means no page committed, so no event exists. The system-admin check stays in the command, inside the lock transaction.
- **History and CSV replacements:** each command takes the lock as today (history keeps its force-clear), then writes and appends `authoring_content_replaced` with `reason` (`history_restore`, `json_edit`, `attribute_edit`, `metadata_csv`, `parameter_csv`) in one transaction. The in-place attribute edit and metadata CSV keep updating the revision in place; the event records the field diff, never the full content.

Every task receives the `Context` built in the LiveView before the task starts; Scenario and Automation callers pass their own.

### 4.6 Catalog, field policy, and context changes

- Remove `project_ownership_changed` from `definitions.ex`, `event_examples.ex`, and `released_event_names.txt` (section 3.4).
- `project_created`, `project_duplicated`, `project_imported`: `affected_kinds: [:author]`, `affected_required: true` (the owner). `project_imported` and the `destructive_content` family allow only `:succeeded`. The project family admits the system actor for technical setup (end-to-end fixtures, seeding).
- Detail keys: `destructive_content` gains `removed_activity_ids`, `reason`, `remapped_activity_count`; `project_settings` gains `blueprint_count`, `experiment_id`, `alternatives_group_id`.
- Pseudo keys: `visibility_grants`, `enabled_activities`, `alternatives_groups`, `experiment_status`, `experiment_conditions`, `experiment_definition` (project settings); `selection_rules` (authoring configuration); `triggers` (DOT). Each is declared in `Fields.schema_sources/0` with what it stands for; the field-policy drift test classifies any new schema involved (`ProjectVisibility`, `ActivityRegistrationProject`, experiment tables).
- The legacy adapter drops `project_published` and `google_doc_imported`.
- No new system actor: Scenarios and Automation use `playwright_setup`; seeders use it too, as technical setup.
- Regenerate `docs/design-docs/audit-log-events.md` at every checkpoint that changes the catalog.

## 5. Data Flow & Edge Cases

Main flow: the transport builds `Context.for_actor(author, source: :ui | :api | :scenario)`; the facade opens or joins the transaction, locks the target, reads the before-state, runs the moved write, diffs under the field policy, appends events (any failure rolls everything back), and the transport runs broadcasts, lock release, and redirects after commit.

| Situation | Required result |
| --- | --- |
| Domain validation or lock failure | No change, no event; the existing error reaches the UI |
| Audit insert failure, missing partition | Mutation rolled back; safe error and flash; the editor keeps its unsaved state |
| Autosave with only text changes | Revision saved, no event |
| Autosave removing an activity reference | One `authoring_content_removed` per removed activity |
| Publish form change without a value change | No write, no event |
| Overview form with a key outside its allowlist | `:protected`; nothing written |
| Concurrent publication | Existing lock check; only the committed publication records an event |
| Collaborator removal of the owner | Existing refusal; no event |
| Invitation token insert fails | Account invitation, collaborator row, and events rolled back |
| Bulk activity delete with one failure | Whole batch rolled back, as today; no events |
| Media delete with IDs from another project | Today's behavior (TRIAGE-2622); events carry each row's real project |
| Media already deleted | No event for that row |
| Ingest failure at any step | Project, publications, and all events rolled back |
| Google Doc page creation fails after media upload | Media rows and S3 objects stay, as today; no event |
| Repair with some pages failing | Events only for committed pages; `:partial` result unchanged |
| Repair finding nothing to fix | `:completed`, no event |
| History restore while another author holds the lock | Force-clear stays (content-admin tool); the event records the restore |
| Metadata CSV with failing rows | Successful rows committed with one event each, as today |
| Project or resource renamed or deleted later | Event-time snapshots unchanged |

No schema migration is planned.

**Behavior changes callers will see:** the audited writes fail when the audit insert fails; `update_project/2` rejects settings keys; the survey, visibility-grant, alternatives, and history writes become transactional; collaborator invitation database writes become atomic; `auto_update_sections` stops writing unchanged values.

## 6. Test Plan

Same policy as PR-03: unrelated fixtures need no audit; each command gets tests of its real mutation-and-event transaction, plus transport tests where a user-visible path changes. Existing suites are adapted, not removed. Audit-insert failures use the `pg_temp` trigger with `capture_log`; concurrency uses `Sandbox.unboxed_run` with scoped cleanup of committed audit rows.

- Unit and component:
  - Protected-key rejection of `update_project/2` and of each settings allowlist.
  - `DotPolicy.triggers/1` for every trigger location, prompt truncation, and path-based diffs.
  - Content-save classification: text-only save, removed activity, selection rule change, objective attach and detach, `ai_enabled`, trigger edit, and combinations in one save.
  - Catalog examples and contracts for every changed event; field-policy drift with the new schemas and pseudo keys; `released_event_names.txt` without `project_ownership_changed`.
- Integration, per block:
  - **Projects:** create, duplicate, delete, publish (including publish inside ingest and inside an outer Multi), working-publication bookkeeping without events, owner as affected author, rollback on audit failure. The existing `project_published` assertions in `test/oli/auditing_test.exs` and `legacy_adapter_test.exs` adapted.
  - **Collaborators:** invitation (new and existing author), acceptance by both paths, rejection, removal, owner refusal, partial failure rollback.
  - **Settings:** each settings caller, no-op writes, attributes embed diffs, grants add and remove, activity availability, experiment transitions, alternatives create, edit, and delete, survey create and delete, learning-model upgrade with blueprints, trigger switch.
  - **Destructive:** curriculum removal with cascade, unattached delete from each LiveView, activity and bank delete (single, bulk, in-place lock path), media delete including another project's IDs and already-deleted rows, alternatives and bibliography deletion. Objective deletion is tested with the other objective operations in block 4.
  - **Configuration:** page options, React editor saves through `resource_controller.ex`, adaptive saves, activity edits with triggers and objectives, objective operations from the LiveView and API, curriculum moves.
  - **Imports and replacements:** ingest success and failure, Google Doc success and page failure, repair completed, partial, failed, and nothing-to-fix, history restore, JSON edit, attribute edit, both CSV imports with failing rows; marker scans for Google file IDs and URLs.
  - **Scenarios:** project, publish, clone, collaborator, objectives, bank, and page directives with the represented author; bootstrap under `playwright_setup`.
  - The regression command in `plan.md` phase 4, plus `test/oli/clone_test.exs`, `test/oli_web/controllers/project_controller_test.exs`, `test/oli_web/live/workspaces/course_author/overview_live_test.exs`, `publish_live_test.exs`, `test/oli_web/live/project_visibility_test.exs`, `test/oli_web/live/collaborators/invitations/invite_view_test.exs`, `test/oli/interop/ingest_test.exs`, and `test/oli/google_docs/import_test.exs`.
- Manual checks:
  - Boundary forbidden-reference check per new facade, recorded and not committed.
  - Latency and query counts at checkpoint F: page autosave (text-only and with activity removal), publication of a large project, ingest of a sample archive, repair of a project with shared activities. Review threshold `max(10 ms, 20% of baseline p95)`.
  - Full `mix test` at the final gate (Scenario handlers and seeders change).

Database safety: every `mix test` run targets `oli_test`, which needs no backup. Verify `DATABASE_URL` is unset first.

## 7. Risks & Open Questions

- Risks:
  - **TRIAGE-2622:** the media API checks no project access, and deletion filters only by ID; any author can list, upload, and soft-delete other projects' media (confirmed with a temporary test on 2026-11-13). PR-04 records the real project of each deleted row and does not fix the authorization.
  - **TRIAGE-2569:** live navigation can skip role-specific admin plugs; the ingest and history tools inherit it.
  - **Generic revision writers stay public.** `Resources.create_revision_from_previous`, `Resources.update_revision`, and `ChangeTracker.track_revision` cannot move behind the Boundary. The final caller inventory greps every use and classifies it; Scenario and seeder writes that bypass editors are excluded on purpose.
  - **Autosave cost.** Every page save now extracts triggers and selection rules twice. Checkpoint F measures it; if it exceeds the threshold, the extraction runs only when the content hash changed.
  - **Size.** Five facades, the editors' writers, many LiveViews and controllers, and Scenario handlers. Checkpoints A–F keep review incremental within one PR.
  - **Objective deletion is not atomic with its detachments** (they run as separate page and activity edits before the delete). Each step records its own committed change; making them one transaction would change behavior and is not planned.
- Owner decisions (2026-11-13):
  - Editors' writers move behind `Oli.Authoring.Audited` (section 3.1, option A).
  - `project_ownership_changed` is removed; ownership is recorded at creation (section 3.4).
  - Prompts are recorded up to 2,000 characters with a truncation marker (section 4.4).
  - The media authorization gap goes entirely to TRIAGE-2622; PR-04 does not change media behavior.
- Owner decisions (2026-11-16):
  - Archive imports write their late labels and survey link through `complete_import/3`, with no event of their own (section 4.2).
  - Experiment edits record `experiment_definition` under `project_settings_changed`, including participating sections, rather than a separate event family (section 4.2).
  - The experiment configuration writers move behind the Boundary, like the other writers in this PR, rather than staying public in `Oli.Experiments` (section 4.2).
  - Objective deletion moves to block 4 with the other objective writers, since they share `learning_objectives_changed` and `ObjectiveEditor` (section 2.1).
  - Only the `delete` writers of `ResourceEditor` and `BibEntryEditor` move behind the facade; creating and editing tags, bibliography entries, and other resources is ordinary content editing, which this PR does not audit (section 3.1).
- Owner decisions (2026-11-17):
  - `Oli.Authoring.Audited` keeps one facade; its private modules are split by area, with the page, activity, objective, and curriculum writes in `Pages`, `Activities`, `Objectives`, and `Curriculum` (section 3.2).
  - A save that removes activity references records one `authoring_content_removed` per activity (section 4.4).

## 8. Definition of Done

### Design gate

- [x] Requirement coverage is explicit (section 2), with deferred and excluded scope distinguished.
- [x] Interfaces are concrete (section 4), including actor rules, event mapping, and composition inside existing transactions.
- [x] Test plan covers main and edge paths (section 6).
- [x] Validation passes (`validate_work_item.py --check design`).
- [x] Owner decisions recorded in section 7.
- [x] Owner approves the design before checkpoint A (2026-11-13).

### Implementation checkpoints after approval

Each checkpoint pauses for owner review, keeps `phase-4-execution.md` current, and is not permission to commit.

1. **A — Projects, publishing, collaborators.** Catalog changes; `Oli.Authoring.Audited` and `Oli.Publishing.Audited` with the Boundary check; project create, duplicate, delete, import creation; publication; collaborators; legacy adapter without `project_published`.
2. **B — Project settings and project DOT.** `Oli.Activities.Audited` and `Oli.Experiments.Audited`; settings commands and allowlists with the `update_project/2` restriction; grants, activity availability, experiments, alternatives, survey, learning model, trigger switch.
3. **C — Destructive content and media.** Removal writers moved; curriculum removal, unattached delete, activity and bank deletion, media, alternatives, and bibliography deletion.
4. **D — Authoring configuration and content DOT**, reviewed in four steps: D1 `DotPolicy` and `edit_page`; D2 `edit_activity` with the `ActivityEditor` and `ActivityBank` writers; D3 objectives (including deletion); D4 page options and curriculum moves, with the DOT interface note in `plan.md` phase 5. The `PageEditor`, `ActivityEditor`, `ActivityBank`, and `ObjectiveEditor` writers move behind the facade.
5. **E — Imports, repairs, replacements.** Ingest, Google Doc import (legacy adapter without `google_doc_imported`), repair, history, both CSV imports.
6. **F — Final verification.** Format; `mix compile --warnings-as-errors` in dev, test, and playwright; affected and full suites; latency evidence; `harness-review` (security, performance, Elixir, UI); work-item validation; event reference regenerated; caller inventory closed against the diff.

No commit, push, PR, Jira change, or change to `handoff.md` is part of this design. PR-04's draft base is `sub-task/MER-6113-audit-log-coverage-identity-and-platform-administration`, opened with the caution block copied from #7042.
