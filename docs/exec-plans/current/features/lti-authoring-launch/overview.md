# LTI External Tool Authoring and Availability

Last updated: 2026-09-23

Related ticket: [MER-5978 — Author-configured LTI deep links that persist from projects to course sections](https://eliterate.atlassian.net/browse/MER-5978).

## Problem and Intended Outcome

An author should be able to configure MyProse writing activities once and carry those selections into new course sections. Instructors should not have to open and configure every activity before students can use the course.

Extend Torus's existing LTI External Tools feature so authors can establish selections in project authoring and product templates, then preserve them when creating or copying sections. MyProse is the primary validation tool; the implementation should support other LTI 1.3 tools with compatible portable deep-link configuration.

Separately, let tool administrators restrict which projects may add a private external tool through Advanced Activities → “+ Activities and Tools.”

## Portable Deep-Link Configuration

Use the approach described in the [LTI Advantage Implementation Guide, section 4: Course Copy and Resource Links](https://www.imsglobal.org/spec/lti/v1p3/impl#course-copy-and-resource-links): preserve the tool-returned URL and `custom` parameters so the tool can identify the selected resource after copying into a different context.

A compatible tool can use that copied configuration without requiring an instructor to repeat resource selection. Custom parameters may contain configuration values or references to configuration held by the tool. Launches still carry the destination's context and the launching user's identity. Not every LTI tool supports this workflow.

### Example: Configure Once and Carry the Selection Forward

An author chooses “Select Resource” in a project or template, then selects cover-letter writing in drafting mode inside the tool. The tool returns an LTI deep-link response containing a selected resource such as:

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

1. **Save the selection.** After validating the response, Torus saves a project selection as a separate versioned resource associated with the activity, or a template selection in its existing section deep-link record. The stored `custom` value is the object supplied by the tool: `{"writing_type":"cover_letter","mode":"drafting"}`. Torus also stores the selected URL and descriptive metadata. Project selection changes follow the revision/publication lifecycle; template selection changes update the template's record.
2. **Create the destination.** For project → template or project → section creation, Torus reads the selection revision from the chosen publication and creates a destination section deep-link record. For template → section inheritance and checkbox-enabled section copying, Torus clones the source's section deep-link record. Each new record belongs to the destination and references its corresponding activity resource, preserving the tool's URL and `custom` values.
3. **Launch the activity.** Torus uses the destination's selection record and sends its custom values in the LTI launch claim `https://purl.imsglobal.org/spec/lti/claim/custom`, together with the destination's launch context and the current user's identity.
4. **Use the saved configuration.** If the tool treats those custom values as the authoritative activity configuration, it launches cover-letter writing in drafting mode in the new section without requiring the instructor to select the resource again. This is the portability behavior the enhancement relies on: the copied configuration remains usable when the launch context changes.

### Tool Compatibility and Independent Destination Changes

**Problem:** What tool-side configuration behavior is required for independent destination changes, especially when custom parameters reference shared content?

This is a tool compatibility and documentation concern. Torus preserves independent selection records for each destination: changing one destination's saved URL or `custom` values does not change source or sibling records. The tool determines whether referenced configuration or content is shared.

- With configuration values such as `{"writing_type":"cover_letter","mode":"drafting"}`, changing one destination's selection to review mode leaves other destinations' saved values unchanged. A tool that treats those values as authoritative can apply each destination's configuration independently.
- With a reference such as `{"configuration_id":"abc123"}`, copied selections initially reference the same tool-side configuration. Editing `abc123` inside the tool may affect every destination that references it. For independent changes, the tool must create a separate configuration and return its new identifier, or otherwise scope changes to the destination.

Shared references can support portable selections without supporting independent editing. Document the tool's behavior for authors and instructors, and validate it with MyProse. No additional Torus storage mechanism is required for this distinction.

## Template Inheritance

A product/template is represented by a section blueprint. Selecting a resource through template preview already persists a deep link, and launching that selection in preview has been confirmed to work.

The missing behavior is inheritance during section creation:

- Copy existing template deep-link selections into records owned by the new section, preserving their selected resource and configuration.
- Leave activities without a template selection unconfigured. Do not create placeholder records or fill missing selections from the project's current configuration.
- Allow instructors to change the new section's selections through the existing workflow.

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

Add “Select Resource” and “Change Selection from Tool” to the project authoring activity UI. Use the existing integration-level `LtiExternalToolActivityDeployment.deep_linking_enabled` setting and author permissions to govern access.

Persist project selections as separate versioned resources and use the chosen publication's selections to initialize corresponding records when creating a template or a section directly from that project. The intended paths are:

- Project → template → section.
- Project → section.

Each destination owns its selection records. Later edits to a project's or template's selections must not automatically overwrite existing destination records. An authorized author or instructor can subsequently change the selection in the context being edited. Preserve the existing delivery configuration workflow.

## Project Selection Storage and Publication

**Problem:** How will project selections be stored and associated with the publication used to create a template or section, so later draft edits do not silently affect published content?

Introduce an `lti_deep_link_selection` resource type with its own revisions and publication mappings. Each selection belongs to an activity resource; store that association on the selection side, rather than in the activity's editable content. The selection revision stores the tool-returned URL, `custom` values, and descriptive metadata. Torus's existing secondary-resource pattern provides a precedent for associating an independently versioned resource with an activity.

- Each successful authoring configuration change, including clearing a selection, creates a new selection revision and updates its mapping in the project's working publication. Published selection revisions remain unchanged.
- Publishing captures the activity and selection revisions in the same publication. Creating a template or section resolves the selection from that specific publication, never from the latest draft.
- If that publication has no configured selection for an activity, create no destination deep-link record. Clearing a selection must also follow the revision/publication lifecycle, preserving older publications' selections.
- Template and section selections continue to use `lti_section_resource_deep_links`. They are independent destination records initialized from the published project selection or copied source context.
- Publication change detection, activity duplication/remixing, deletion, and export/import must account for the new resource and preserve or rewrite its owning-activity association as appropriate.

For example, publication A can retain MyProse's cover-letter drafting configuration while the working publication changes to proposal review. A section created from publication A still receives cover-letter drafting; the draft change becomes available for project-based creation only after publication B is published. Neither change overwrites existing destination selections.

### Configuration Returns and Editor State

The separate selection resource is preferred over storing the selection directly in the activity resource's revision because the client-side activity editor still has its previous model and holds an editing lock when the tool returns. If the callback changed the activity's content, a subsequent editor save could overwrite the newly stored selection with that stale model.

The callback updates the separate selection resource, leaving the activity's content unchanged. Ordinary activity saves therefore cannot overwrite the selection. Refresh the selection's displayed status after configuration; replacing the activity editor's model or adding page-wide locks is unnecessary for this purpose.

Correlate the return with the initiating author and activity using a short-lived Torus-signed Phoenix token in `deep_linking_settings.data`, which the tool returns unchanged. Use a signing salt dedicated to deep-link configuration and enforce a maximum token age. Include the author, project, activity, expected tool deployment, and the deep-link selection resource's starting revision ID (or its absence). This self-contained token requires no server-side pending-request record.

Capture only the deep-link selection resource's revision ID, or its absence if no selection resource exists. On return, save only if that selection revision is unchanged, or still absent. A revision representing a cleared selection still has an ID to track. The activity resource has a separate revision ID that is not part of this comparison; edits to the activity resource do not affect this check. This selection revision check is a Torus concurrency safeguard, not an LTI requirement.

Apply standard LTI validation to the tool-signed response JWT, including signature, issuer/audience, lifetime, nonce/replay checks, message type, version, deployment, and accepted content items. Separately verify the returned Phoenix token's Torus signature and age; the tool's signature alone does not prove that `data` is unchanged from what Torus issued. Verify that the activity still exists in the project and uses the expected tool integration, and recheck the initiating author's permissions and applicable editing lock. Compare the current draft selection revision ID with the captured ID, rejecting a mismatch or the creation of a previously absent selection. Because every configuration change creates a new selection revision, an older configuration window cannot overwrite a newer saved selection. Keep concurrency checks scoped to revision identity; do not add content hashes or timestamp comparisons.

Serialize selection changes and perform the revision comparison, new revision creation, and working-publication mapping update atomically, including first-time selection creation. Once a response is saved, its captured selection revision no longer matches, preventing it from being applied again without a separate consumed-request registry. This protection uses the persisted selection state; signing alone does not make a token single-use. Cancellation, validation failures, and failed saves preserve the previous selection.

## LTI Resource-Link Identity and Compatibility

**Problem:** How will destination LTI resource-link identity be handled separately from Torus resource identity while maintaining compatibility with existing integrations?

Use context-specific LTI `resource_link.id` values for new projects, templates, and sections while preserving the IDs used by existing contexts. Torus's internal activity `resource_id` can remain the same across contexts; the LTI link ID identifies its use in a particular context.

- Persist an identity-format version on the owning project or section. Existing contexts use the legacy resource-based format; newly created contexts use the new format.
- Derive new-format IDs from the context type, immutable context ID, and activity resource ID, for example `section:100:resource:42`. Repeated launches of the same activity in that context retain the same ID.
- Creation and copy operations explicitly assign the new identity format to the destination, even when the source uses the legacy format. Preserve the copied URL/custom configuration while generating the link identity from the destination context.
- Selecting, replacing, or clearing deep-link configuration does not change the link ID. Do not derive it from the selection record's ID.
- Existing contexts retain their current IDs to avoid disrupting tool-side associations. Converting those contexts is a separate, tool-tested migration; this enhancement does not correct their existing cross-context identity reuse.

This policy implements distinct link identity for new copies while protecting existing integrations. With MyProse, verify that destination sections receive different link IDs but identical copied custom configuration, and that both launch without instructor setup.

## Project-Scoped Tool Availability

Add Public/Private availability to each external tool deployment configuration. Migrate all existing tool configurations to Public for backward compatibility. New tool configurations default to Private. This visibility migration preserves existing deployment status and project associations.

- Public tools may be added to any project, subject to existing platform enablement and project permissions.
- Private tools may be added only to explicitly specified projects.
- Enforce eligibility in both the “+ Activities and Tools” UI and the server-side addition operation.
- Keep eligibility grants separate from the `activity_registration_projects` association that records whether a project has added and enabled a tool.
- Making a tool private or removing a project grant must not remove existing associations, prevent their management, or block existing activity launches solely because of the scope change.

Institution scoping is outside this epic and may be considered as a future follow-on.

## Validation with MyProse

Demonstrate the complete author-to-student workflow using MyProse:

- Configure activities with distinct writing types, such as proposal and cover-letter writing, and cover both drafting and review modes.
- Preserve the selected writing type and mode through template → section, project → template → section, project → section, and checkbox-enabled section → section copying.
- Confirm persistence after reload and successful student launch without initial instructor configuration.
- Confirm later draft selection changes do not affect creation from an older publication, and ordinary activity edits after a configuration return do not overwrite the saved selection.
- Confirm an instructor can change an inherited selection without changing source or sibling Torus selection records. Verify whether MyProse configuration edits are independent or affect shared tool-side content, and document the observed behavior for instructors.
- Confirm unchecked section copying and unconfigured source activities produce no destination selection records.
- Confirm the selection-copy checkbox defaults to checked and follows the same full-copy/select-all behavior as the other copy-rules checkboxes.

## Documentation

Provide author/instructor guidance for selection, inheritance, local changes, and section-copy behavior, including whether tool-side configuration edits affect other destinations. Provide tool-developer guidance explaining the portability contract, the cited LTI copy guidance, launch context, and how to support independent destination changes when configuration is referenced through `custom`. Explain Public/Private availability for tool administrators.

Detailed schema choices, implementation tasks, and verification will be developed in subsequent specifications.
