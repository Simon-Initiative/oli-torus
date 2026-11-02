# LTI External Tool Authoring and Deep-Link Inheritance

Last updated: 2026-10-05

Related ticket: [MER-5978 — Author-configured LTI deep links that persist from projects to course sections](https://eliterate.atlassian.net/browse/MER-5978).

## Problem and Intended Outcome

An author should be able to configure LTI activities once and carry those selections into new course sections. Instructors should not have to open and configure every activity before students can use the course.

Extend Torus's existing LTI External Tools feature so authors can establish selections in project authoring and product templates, then preserve them when creating or copying sections. MyProse is the primary validation tool; the implementation should support other LTI 1.3 tools with compatible portable deep-link configuration.

## Portable Deep-Link Configuration

Use the approach described in the [LTI Advantage Implementation Guide, section 4: Course Copy and Resource Links](https://www.imsglobal.org/spec/lti/v1p3/impl#course-copy-and-resource-links): preserve the tool-returned URL and `custom` parameters so the tool can identify the selected resource after copying into a different context.

A compatible tool can use that copied configuration without requiring an instructor to repeat resource selection. Custom parameters may contain configuration values or references to configuration held by the tool. Launches still carry the destination's context and the launching user's identity. Not every LTI tool supports this workflow.

### Example: Configure Once and Carry the Selection Forward

In project authoring, an author chooses a launch role (Developer or Instructor), selects the Deep Link launch type, and chooses “Select Resource.” In a template, the author uses the existing selection workflow. The author then selects cover-letter writing in drafting mode inside the tool. The tool returns an LTI deep-link response containing a selected resource such as:

```json
{
  "type": "ltiResourceLink",
  "title": "Cover-letter practice",
  "url": "https://tool.example/lti/launch",
  "custom": {
    "writing_type": "cover_letter",
    "mode": "drafting"
  }
}
```

The parameter names are illustrative. The tool defines the `custom` keys and values; Torus preserves them.

1. **Save the selection.** After validating the response, Torus saves a project selection in the existing activity revision’s `content` field, or a template selection in its existing section deep-link record. No additional authoring resource is created. The stored `custom` value is the object supplied by the tool: `{"writing_type":"cover_letter","mode":"drafting"}`. Torus also stores the selected URL and descriptive metadata. Project selection changes follow the revision/publication lifecycle; template selection changes update the template's record.
2. **Create the destination.** For project → template or project → section creation, Torus reads the selection from the activity revision’s content in the chosen publication and creates a destination section deep-link record. For template → section inheritance and checkbox-enabled section copying, Torus clones the source's section deep-link record. Each new record belongs to the destination and references its corresponding activity resource, preserving the tool's URL and `custom` values.
3. **Launch the activity.** Torus uses the destination's selection record and sends its custom values in the LTI launch claim `https://purl.imsglobal.org/spec/lti/claim/custom`, together with the destination's launch context and the current user's identity.
4. **Use the saved configuration.** If the tool treats those custom values as the authoritative activity configuration, it launches cover-letter writing in drafting mode in the new section without requiring the instructor to select the resource again. This is the portability behavior the enhancement relies on: the copied configuration remains usable when the launch context changes.

### Tool Compatibility and Independent Destination Changes

**Problem:** What tool-side configuration behavior is required for independent destination changes, especially when custom parameters reference shared content?

This is a tool compatibility and documentation concern. Torus preserves independent selection records for each destination: changing one destination's saved URL or `custom` values does not change source or sibling records. The tool determines whether referenced configuration or content is shared.

- With configuration values such as `{"writing_type":"cover_letter","mode":"drafting"}`, changing one destination's selection to review mode leaves other destinations' saved values unchanged. A tool that treats those values as authoritative can apply each destination's configuration independently.
- With a reference such as `{"configuration_id":"abc123"}`, copied selections initially reference the same tool-side configuration. Editing `abc123` inside the tool may affect every destination that references it. For independent changes, the tool must create a separate configuration and return its new identifier, or otherwise scope changes to the destination.

Shared references can support portable selections without supporting independent editing. Document the tool's behavior for authors and instructors, and validate it with MyProse. No additional Torus storage mechanism is required for this distinction.

## Current Storage and Required Creation Steps

Today, inserting an LTI activity creates an ordinary activity resource and revision. The page stores an `activity-reference` to that activity resource, and the publication resolves its revision. The revision’s `activity_type_id` identifies the registered tool. Its `content` currently contains presentation settings (`openInNewTab` and optional `height`) and the standard activity authoring structure (`authoring.parts` and initially empty `authoring.previewText`).

Course sections store deep-link selections separately in `lti_section_resource_deep_links`, with one record per `(section_id, resource_id)`. The existing “Select Resource from Tool” workflow saves the returned type, URL, `custom`, title, and text in that record; changing a selection updates it without changing the activity revision. Later launches use the record’s URL and custom parameters with the current section and user context. These section records are not versioned resources.

A product/template is represented by a section blueprint and uses the same selection table. Selecting a resource through template preview already persists a deep link, and launching that selection in preview has been confirmed to work. The Phase 2 prototype implements initialization for direct project → course section creation. Project → template initialization and template → course section copying remain to be implemented. The required behavior for all three paths is described below.

| Creation path | Source of selection | Required step |
| --- | --- | --- |
| Project → template | LTI activity revision content from the chosen publication | Create a `lti_section_resource_deep_links` record for each initialized activity, owned by the new template’s section ID. |
| Project → course section | LTI activity revision content from the chosen publication | Create a `lti_section_resource_deep_links` record for each initialized activity, owned by the new course section’s ID. |
| Template → course section | The template’s existing `lti_section_resource_deep_links` records | Copy selections into new records owned by the new course section. Use the template’s current selections, including any changes made in template preview. |

Run selection initialization after the destination section and corresponding activity resources are available, as part of the creation transaction. Preserve the selected type, URL, `custom`, title, and text, and associate each record with the corresponding destination activity resource. Create records only for activities included in the destination. Creation must not report success with required selections only partially initialized.

For project-based creation, read the published activity content, never the latest project draft. For template-based creation, copy the template’s records, never reinitialize from the project’s activity content. If the source has no selection for an activity, create no destination record; do not create placeholders or restore a missing or cleared template selection from the project.

Thus, project → template → section involves two explicit steps: initialize the template’s records from published activity content, then copy the template’s records when creating a course section. Direct project → section creation uses the same publication-based initialization without an intermediate template.

Each destination owns its records. Later source changes do not automatically overwrite existing destinations. Allow instructors to change inherited section selections through the existing workflow.

## Template Configuration

Optional: add an **“LTI External Tools”** link to the template overview UI, using the existing section Manage page's **“LTI 1.3 External Tools”** link and listing as the basis. Adapt that experience for templates, retaining tool grouping, search, and navigation to the content containing each activity. Add configuration status and a badge counting activity instances whose integrations support deep linking but have no saved selection, making it easy to find and configure them.

## Section Copy Support

The Course Copy feature must also support section → section selection copying. Add a copy-rules checkbox labeled exactly **“LTI External Tool Deep Link Selections.”**

- **Checked:** clone existing source selections for activities included in the new section, preserving URL/custom configuration and assigning destination ownership.
- **Unchecked:** create no destination selection records, including through project/template fallback.
- An unconfigured source activity remains unconfigured. Other copy rules determine which activities are included; this checkbox controls their deep-link selections.
- Copying selections must not copy learner attempts, submissions, grades, or other learner data. Subsequent selection changes in the destination must not update source or sibling Torus records.

Reuse the template inheritance behavior and integrate with the Course Copy feature described in `docs/exec-plans/current/epics/course_replication/course_copy/informal.md`.

### Checkbox Defaults and Copy Controls

**Problem:** What should the section-copy checkbox's initial state and relationship to full-copy/select-all controls be?

The checkbox defaults to checked. It follows the same full-copy/select-all behavior as the other copy-rules checkboxes, including how individual changes affect those controls. No special selection behavior is needed for LTI deep-link selections.

## Project Authoring

Extend the authoring view of each LTI activity with two independent choices before launching the tool:

| Control | Choices | Behavior |
| --- | --- | --- |
| Launch as | **Developer** or **Instructor** | Set the launch’s LTI context role to ContentDeveloper or Instructor, respectively. |
| Launch type | **Regular** or **Deep Link** | Send a regular resource-link launch or open the tool’s deep-link selection workflow, respectively. |

Support all four combinations when the integration supports deep linking: Developer + Regular, Instructor + Regular, Developer + Deep Link, and Instructor + Deep Link. Default to Developer + Regular to preserve the existing authoring launch behavior. Make both controls visible before launching so the author can deliberately choose how to enter the tool.

- **Regular:** launch an `LtiResourceLinkRequest` with the selected role. When the activity has a saved selection, use its URL and `custom` values from the current authoring revision; otherwise use the integration’s default launch URL. A regular launch does not itself save or replace the deep-link selection in Torus.
- **Deep Link:** launch an `LtiDeepLinkingRequest` with the selected role and the project/activity return correlation described below. Provide “Select Resource” or “Change Selection from Tool,” according to whether the activity already has a saved selection. Validate the returned selection and save it in the activity revision’s content, then refresh the editor model and displayed selection.
- Offer Deep Link only when the existing integration-level `LtiExternalToolActivityDeployment.deep_linking_enabled` setting permits it. Enforce author permissions and supported launch choices on the server as well as in the UI.
- Carry the selected role and launch type through launch-details generation, the login hint, and authorization redirect so the signed launch reflects the author’s choices. Treat Developer/Instructor as the selected context role; preserve applicable platform roles separately. The launch continues to identify the initiating author and the project context. Choosing Instructor does not impersonate a course instructor or switch to a course-section context.
- Treat these controls as authoring launch options, not as part of the tool-returned selection. They do not determine learner roles or launch types in created templates or course sections.

Persist project selections in the existing activity revision’s `content` field and use the chosen publication’s activity revisions to initialize corresponding records when creating a template or a section directly from that project. The intended paths are:

- Project → template → section.
- Project → section.

Each destination owns its selection records. Later edits to a project's or template's selections must not automatically overwrite existing destination records. An authorized author or instructor can subsequently change the selection in the context being edited. Preserve the existing delivery configuration workflow.

## Project Selection Storage and Publication

**Problem:** How will project selections be stored and associated with the publication used to create a template or section, so later draft edits do not silently affect published content?

Store the selected type, URL, `custom` object, and descriptive metadata in a dedicated optional field within the LTI activity revision’s `content`, alongside the existing presentation settings and authoring structure. The field name will be finalized in the detailed schema. Preserve tool-defined custom keys and values.

No new resource type, separate selection resource, or separate publication mapping is needed. The page continues to reference the existing activity resource, and the activity’s own revision/publication lifecycle versions its selection together with its other content.

- Saving, replacing, or clearing a project selection uses the activity’s existing editing and revision lifecycle. Published activity revisions remain unchanged.
- Publishing captures the activity revision containing the selection. Project-based template or section creation reads that exact revision’s content and creates the destination selection record as described above.
- An absent or cleared selection in that published activity content produces no destination deep-link record. Older publications retain their prior selections.
- Template and course-section selections continue to use `lti_section_resource_deep_links`; they are independent destination records initialized from published activity content or copied from the source template/section.
- Verify that existing activity duplication/remixing and export/import preserve the added content field and that publication change detection recognizes selection edits through the normal activity revision lifecycle.

For example, publication A can retain MyProse's cover-letter drafting configuration while the working publication changes to proposal review. A section created from publication A still receives cover-letter drafting; the draft change becomes available for project-based creation only after publication B is published. Neither change overwrites existing destination selections.

### Configuration Returns and Editor State

The selection is part of the activity model, so the configuration return must coordinate with the existing editor and its editing lock. Persist pending activity edits before starting configuration and capture the resulting activity revision ID. On successful return, update only the selection field while preserving the other activity content, then synchronize the editor with the saved model and revision before allowing further saves. Coordinate in-flight autosaves so a stale client model cannot overwrite the new selection. Refresh the displayed selection status as part of that synchronization.

Correlate the return with the initiating author and activity using a short-lived Torus-signed Phoenix token in `deep_linking_settings.data`, which the tool returns unchanged. Use a signing salt dedicated to deep-link configuration and enforce a maximum token age. Include the author, project, activity, expected tool deployment, and the activity’s starting revision ID. This self-contained token requires no server-side pending-request record.

Apply standard LTI validation to the tool-signed response JWT, including signature, issuer/audience, lifetime, nonce/replay checks, message type, version, deployment, and accepted content items. Separately verify the returned Phoenix token’s Torus signature and age; the tool’s signature alone does not prove that `data` is unchanged from what Torus issued. Verify that the activity still exists in the project and uses the expected tool integration, and recheck the initiating author’s permissions and applicable editing lock.

Compare the current draft activity revision ID with the captured ID and reject a stale return rather than overwriting intervening edits. This comparison now covers ordinary activity edits as well as selection changes. Serialize the comparison, selection update in a new activity revision, and working-publication mapping update atomically. Verify that this path advances revision identity even when the editor already holds a lock, so a successfully saved response cannot be applied again using the same starting revision. Signing alone does not make a token single-use. Keep concurrency checks scoped to revision identity; do not add content hashes or timestamp comparisons.

Cancellation, validation failures, stale returns, and failed saves preserve the previous selection and any independently saved activity edits.

## LTI Resource-Link Identity and Compatibility

**Problem:** How will destination LTI resource-link identity be handled separately from Torus resource identity while maintaining compatibility with existing integrations?

Use context-specific LTI `resource_link.id` values for new projects, templates, and sections while preserving the IDs used by existing contexts. Torus's internal activity `resource_id` can remain the same across contexts; the LTI link ID identifies its use in a particular context.

- Persist an identity-format version on the owning project or section. Existing contexts use the legacy resource-based format; newly created contexts use the new format.
- Derive new-format IDs from the context type, immutable context ID, and activity resource ID, for example `section:100:resource:42`. Repeated launches of the same activity in that context retain the same ID.
- Creation and copy operations explicitly assign the new identity format to the destination, even when the source uses the legacy format. Preserve the copied URL/custom configuration while generating the link identity from the destination context.
- Selecting, replacing, or clearing deep-link configuration does not change the link ID. Do not derive it from the selection record's ID.
- Existing contexts retain their current IDs to avoid disrupting tool-side associations. Converting those contexts is a separate, tool-tested migration; this enhancement does not correct their existing cross-context identity reuse.

This policy implements distinct link identity for new copies while protecting existing integrations. With MyProse, verify that destination sections receive different link IDs but identical copied custom configuration, and that both launch without instructor setup.

## Validation with MyProse

Demonstrate the complete author-to-student workflow using MyProse:

- Exercise all four authoring role/launch-type combinations and verify the emitted context role and message type. Confirm Developer + Regular is the default and Deep Link is unavailable when disabled for the integration.
- Confirm a regular authoring launch uses the saved selection when present, while a deep-link launch can create or replace that selection under either chosen role. Confirm the launch retains the initiating author’s identity and project context.
- Configure activities with distinct writing types, such as proposal and cover-letter writing, and cover both drafting and review modes.
- Preserve the selected writing type and mode through template → section, project → template → section, project → section, and checkbox-enabled section → section copying.
- Confirm project → template and project → section creation initialize destination selection records from the chosen publication’s activity content. Confirm template → section creation copies the template’s records, including template-local changes, without falling back to project content.
- Confirm persistence after reload and successful student launch without initial instructor configuration.
- Confirm later draft selection changes and clearing do not affect creation from an older publication. Confirm ordinary activity edits after a configuration return do not overwrite the saved selection, and stale or repeated returns cannot overwrite newer activity revisions.
- Confirm an instructor can change an inherited selection without changing source or sibling Torus selection records. Verify whether MyProse configuration edits are independent or affect shared tool-side content, and document the observed behavior for instructors.
- Confirm unchecked section copying and unconfigured source activities produce no destination selection records.
- Confirm the selection-copy checkbox defaults to checked and follows the same full-copy/select-all behavior as the other copy-rules checkboxes.

## Documentation

Provide author/instructor guidance for the Developer/Instructor and Regular/Deep Link launch choices, selection, inheritance, local changes, and section-copy behavior, including whether tool-side configuration edits affect other destinations. Provide tool-developer guidance explaining the portability contract, the cited LTI copy guidance, launch context, and how to support independent destination changes when configuration is referenced through `custom`.

Detailed schema choices, implementation tasks, and verification will be developed in subsequent specifications.
