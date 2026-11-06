# LTI Authoring Launch Prototype Plan

Source: `docs/exec-plans/current/features/lti-authoring-launch/overview.md`

Status: Phase 1 implemented for the project page editor and Phase 2 implemented for direct project → section creation. Live MyProse walkthrough pending.

## Prototype Goal and Scope

Answer two questions with a small, runnable implementation: can an author choose a launch role and type, capture a tool’s deep-link selection in the existing activity content, and then create a course section that launches that selection without instructor setup?

Implement the two phases below in order. Use an existing MyProse integration and a small project as the demonstration path. Reuse existing launch, editor, publication, and section-selection code. This is a prototype, not the complete production feature in the overview: use simple controls, minimal error presentation, and brief manual demonstrations. Do not build a new automated test suite or run broad regression suites for this spike.

Defer project → template initialization, template → section copying, section-copy controls, template management UI, resource-link identity migration, and comprehensive import/export and concurrency hardening. Tool availability scoping is separate work. The prototype creates no new resource type, selection resource, or database table.

## Phase 1 — Flexible Authoring Launches and Selection Capture

**Outcome:** an author can launch as Developer or Instructor using either Regular or Deep Link, and a returned selection survives reload in the activity revision’s content.

1. **Extend the existing LTI activity model.** Add an optional `deepLink` object containing the returned `type`, `url`, `custom`, `title`, and `text`. Preserve the tool’s custom object as supplied. Leave existing presentation settings and `authoring.parts` intact. An absent field means the activity has no saved selection; existing activities need no data migration.

2. **Add two controls and an explicit launch action to the authoring view.** Offer “Launch as: Developer / Instructor” and “Launch type: Regular / Deep Link,” defaulting to Developer + Regular. Keep the choices in local UI state. Enable Deep Link only for integrations with deep linking enabled. Use “Select Resource” or “Change Selection from Tool” for the deep-link action and display the saved selection title. Reuse the existing tool frame/modal rather than building another launch surface.

3. **Carry the choices through the authoring launch request.** Extend the persistence client and project launch-details endpoint, then carry the selected role and type through the login hint to the authorization redirect. Allowlist the two roles and two launch types server-side. Developer maps to the ContentDeveloper context role; Instructor maps to the Instructor context role. Keep the current author identity, project context, and applicable platform roles.

4. **Implement both launch branches.** Regular sends `LtiResourceLinkRequest`, using the saved selection URL/custom when present and the integration’s default URL otherwise. Deep Link sends `LtiDeepLinkingRequest` to the tool’s configuration entry point with settings accepting one `ltiResourceLink` and a project/activity return route. Reuse the existing section deep-link flow as the starting point.

5. **Capture and validate the return.** Add the project return handler. Reuse existing tool-signed JWT validation and single-item/type checks, and correlate the return to the initiating author, project, activity, and deployment using short-lived signed data. Retain project authorization and integration checks. Return the validated selection to the initiating editor; do not treat a browser-supplied content item as a trusted tool response.

6. **Save through the activity editor.** For the smallest prototype, have the editor retrieve the server-validated result, merge it into `model.deepLink`, and use the existing activity edit/save path. Flush pending edits before launching and prevent overlapping configuration launches or edits while selection is pending. This keeps the client model and persisted content aligned instead of having the callback silently rewrite content behind the editor. Cancellation or failure keeps the prior selection. Show completion only after the activity save succeeds. Leave comprehensive stale-window/replay handling for production follow-up.

7. **Demonstrate the result.** Exercise the four role/type combinations against the tool and inspect the resulting launch role/message type. Select a recognizable configuration, reload the editor, and use a regular launch to reopen it. Make one ordinary presentation edit and reload to confirm the saved selection remains.

**Starting code locations:**

- `assets/src/components/activities/lti_external_tool/schema.ts`
- `assets/src/components/activities/lti_external_tool/LTIExternalToolAuthoring.tsx`
- `assets/src/components/activities/lti_external_tool/LTIExternalToolDelivery.tsx` (existing selection modal)
- `assets/src/components/lti/LTIExternalToolFrame.tsx`
- `assets/src/data/persistence/lti_platform.ts`
- `lib/oli_web/controllers/api/lti_controller.ex`
- `lib/oli_web/controllers/lti_controller.ex`
- `lib/oli_web/router.ex`
- `lib/oli/authoring/editing/activity_editor.ex`

**Phase exit:** the selected URL/custom values are visible in persisted activity content, survive an ordinary edit, and drive a subsequent regular authoring launch. Record any MyProse restrictions on role/type combinations rather than expanding the prototype to work around unsupported tool behavior.

## Phase 2 — Initialize Selections on Direct Project → Section Creation

**Dependency:** Phase 1 produces an activity with a saved deep-link selection that can be published.

**Outcome:** a course section created directly from that project’s publication already has the section-owned selection records needed by the existing delivery launch path.

1. **Publish the configured activity.** Use the normal project publication flow. Identify the exact publication chosen for course-section creation; its activity revisions are the source of truth, not the current authoring draft.

2. **Add a step to direct project-based section creation.** Locate the publication-based creation branch in `lib/oli/delivery.ex`. After the new section and its resources are available, initialize its LTI selections within the existing creation transaction. Keep this step scoped to direct project/publication creation so it does not introduce project fallback into template or section-copy paths.

3. **Read initialized LTI activities from that publication.** Resolve the activity revisions included in the destination and inspect their `content.deepLink` values. Skip activities without a selection. Do not create placeholder selections or read a newer working-publication revision.

4. **Create destination selection records.** Reuse `Oli.Lti.PlatformExternalTools` and `lti_section_resource_deep_links`. For each selected activity, save the selected type, URL, custom object, title, and text with the new section’s ID and the corresponding activity resource ID. A failure should fail the creation transaction rather than leave a successfully created but partly initialized section.

5. **Use existing delivery launches unchanged where possible.** The section launch already looks up its selection by section/activity and sends the saved URL/custom with the section context and current user. Confirm the seeded records take this path. Keep the existing instructor “Change Selection” workflow available.

6. **Demonstrate the end-to-end path.** Create a course section directly from the publication and launch the activity as a learner without instructor selection. Inspect the new selection record and confirm the tool opens the authored configuration. Include one unconfigured activity and confirm no record is created for it. Make an unpublished project selection change and create another section from the earlier publication to confirm it still receives the published selection.

**Starting code locations:**

- `lib/oli/delivery.ex`
- `lib/oli/delivery/sections.ex` (`create_section_resources` and publication resolution)
- `lib/oli/lti/platform_external_tools.ex`
- `lib/oli/lti/platform_external_tools/lti_section_resource_deep_link.ex`
- `lib/oli_web/controllers/lti_controller.ex` (existing section launch lookup)

**Phase exit:** a newly created section contains its own selection records and a learner can launch the configured activity without instructor setup. Existing section selections are not rewritten when the project changes.

## Prototype Handoff

### Phase 1 Implementation Notes

The project page editor now offers Developer/Instructor and Regular/Deep Link controls. Deep-link configuration opens in the existing modal/frame. The tool returns signed correlation data, and the callback supplies a short-lived signed result to the frame. The editor retrieves that result through an authenticated endpoint and saves the selection as `content.deepLink` using its existing activity save path. Regular launches reuse that selection. No schema migration or additional resource is involved.

Login hints store the project ID, role, launch type, and request ID to fit the existing 255-character context limit; the signed correlation token is generated during authorization. The prototype's editor save bridge is implemented in the project page editor; other authoring hosts, including standalone activity-bank editing, are not part of this runnable path.

Verification completed: TypeScript checking, targeted frontend lint/format checks, Elixir compilation, 46 existing LTI API/controller checks, and a temporary signed-tool smoke check exercising all four launch combinations, return validation, activity-content persistence, and reuse of saved URL/custom values. The smoke check used a local signed response, not MyProse. Browser interaction and MyProse-specific behavior remain to be demonstrated; no live demo project/publication/section identifiers have been recorded.

### Phase 2 Implementation Notes

Direct publication-based creation in `lib/oli/delivery.ex` now calls `PlatformExternalTools.initialize_section_deep_links/2` after creating the section resources, inside the existing creation transaction. The helper intersects destination resource IDs with the chosen publication's activity revisions and LTI registrations, then inserts section-owned records from `content.deepLink`. It skips absent/null selections and fails creation on invalid selections or failed inserts. Section revision IDs are populated later in creation, so this step resolves revisions directly through publication mappings.

Verification completed: formatting and compilation, existing delivery checks, and a temporary smoke check covering URL/custom/metadata preservation, skipping unconfigured and cleared selections, creating from an older publication after a draft change, independent destination records, and rollback of section creation for an invalid selection. No live course sections were created for this check. The existing section launch and instructor selection-change paths consume these records without modification. Template creation, template inheritance, and section-copy behavior remain deferred.

Live myProse configuration exposed an existing storage limit: its returned description was 401 characters, while section selection URL/title/text columns were limited to 255. Migration `priv/repo/migrations/20261005200125_widen_lti_deep_link_selection_fields.exs` widens these columns to PostgreSQL `text` without truncating tool data. A focused regression verifies long values round-trip unchanged; rollback refuses to shrink the columns while oversized values exist.

### Remaining Demonstration and Production Work

Record the demo project, publication, and section identifiers; the role/type combinations MyProse accepted; and whether the copied custom configuration worked in the destination context. Report observed behavior separately from assumptions about tool-side sharing.

Keep verification to compilation/formatting needed to run the prototype and the short manual demonstrations above. Before production, complete callback concurrency/replay handling and editor recovery, add focused regression coverage, implement template initialization/inheritance and section copying, and resolve context-specific resource-link identity as described in the overview. The prototype retains existing resource-link IDs, so a successful demo does not establish independent tool-side identity across contexts.
