# Configure external tools with Deep Linking

Deep Linking lets an author or instructor choose a resource or configuration inside an external tool and save that selection in Torus. A Regular launch opens the saved selection. Without a saved selection, a Regular launch uses the integration's default configuration.

The external tool must be registered and enabled in Torus, with Deep Linking enabled for its integration. These instructions describe Torus launching an external tool; configuring an LMS to launch Torus is covered in `guides/lti/config.md`.

## Select a resource in a project

1. Open the project page editor and add or open the external-tool activity.
2. Choose **Launch as**: Developer or Instructor. This sets the role sent to the tool while retaining your author identity and project context. Developer is the default; the tool decides how its interface differs for each role.
3. Set **Launch type** to **Deep Link**, then choose **Select Resource** or **Change Selection from Tool**.
4. Select the resource/configuration in the tool's dialog and use the tool's action to return it to Torus.
5. Wait for the page editor to finish **Saving...** and display **All changes saved**. A tool's own confirmation alone does not establish that Torus saved the selection.
6. To try the saved selection, choose **Regular** and **Launch Tool**.

Torus saves pending page and activity edits before opening the selector. Configuration requires editing permission and a supported page-editor host. Closing without returning a selection preserves the existing selection. If saving fails, follow the error shown; if the outcome is uncertain, reload before trying again.

**Selection** displays the tool's title, then its descriptive text, then its URL, and finally **Configured resource** if those fields are absent. Torus uses this same order in authoring and instructor delivery. This label describes saved metadata; Torus does not interpret tool-specific custom parameters to generate a name.

## Publish and create courses

A selection saved in a project is draft content until publication. Publishing captures it with the activity revision.

- A course created directly from a project publication receives that publication's selections for its included activities. Choosing an older publication uses the older selections.
- A template created from a project publication receives its own selections from that publication.
- A course copied from a template or previous course receives the source's current selections, including instructor changes. They belong to mandatory **Content / curriculum** and have no separate copy checkbox.
- Each destination owns independent selections. Later changes to the source do not modify a copy.
- If a copied source has no selection for an activity, the destination also has no selection. Copying does not recover a project default.

When a publication is applied to an existing course, Torus initializes only missing selections for activities included in that course. It preserves every existing selection, including instructor changes, even if the project's newer configuration differs or has been removed. Publishing alone follows the existing course-update settings; the initialization happens when the update is applied.

Adding content through **remix / Add Materials** into a course or template also inherits Deep Links:

- A project source supplies selections from the publication chosen in Add Materials, independently of newer drafts or publications.
- A template source supplies that template's current selections. If a selection is missing or cleared, Torus does not fall back to its project's selection.
- Torus creates independent selections for activities referenced by the added pages that remain when you save. It preserves any selection already present in the destination. Removing added material before saving creates no selection for it.
- Curriculum changes and inherited selections save together; a failed remix does not partially apply them.

## Change a course's selection as an instructor

Open the activity in your course and choose **Change Selection from Tool**, or **Select Resource from Tool** if it is unconfigured. Return a new selection from the tool to save it for this course only. Closing before a selection is committed preserves the prior selection. Closing does not undo a completed save.

The next learner launch uses the course's current selection. Refreshing an embedded activity can launch it with the updated configuration; **Reset answers** is not required. Project, template and sibling-course selections remain independent. Learners cannot configure the tool.

When reopening the selector, Torus supplies the current selection's supported custom parameters as optional hints. A tool may use them to preselect its interface, but that behavior depends on the tool. An apparently fresh selector does not mean the saved selection was lost.

## Dialog ownership and compatibility

Torus owns the dialog wrapper and launch/save/error feedback. The external tool owns the content inside the dialog, its resource catalog and its selection controls.

Torus copies the saved URL and custom data without creating or cloning tool-side resources. Whether a resource works in another course depends on the tool's permissions and support for the copied configuration. Neither independent Torus records nor generic custom hints guarantee tool-side cloning or UI preselection.

There is no reset/clear-selection action in this change. A Regular launch reuses the current selection; changing the launch type does not clear it.

## Migration verification for maintainers

`priv/repo/migrations/20261005200125_widen_lti_deep_link_selection_fields.exs` widens section selection URL/title/text columns to PostgreSQL `text`. Rollback refuses to shrink the fields while any value exceeds 255 characters. Preserve or export those values before deliberately shortening them; rollback never silently truncates them. No blanket backfill is performed.

The actual migration passed a one-off check in a disposable database: up/down/up, null and multibyte-value preservation, and rollback refusal for each oversized field without data loss. The temporary script was removed after execution. Detailed results are recorded in `docs/exec-plans/current/features/mer-6018-lti-deep-linking/plan.md` under Migration Verification Results.

Backend and frontend coverage runs without an external tool. Existing MyProse observations and the deferred complete compatibility walkthrough are recorded in `docs/exec-plans/current/features/mer-6018-lti-deep-linking/informal.md`; they do not establish interoperability with every tool.
