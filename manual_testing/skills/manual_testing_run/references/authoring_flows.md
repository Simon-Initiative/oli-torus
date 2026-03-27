# Authoring Flows

Use this reference when a test case has `domain: authoring`.

## Primary Jobs In Authoring
- open a project overview
- inspect or edit page content
- move through page hierarchy
- verify that an authoring page is editable
- confirm draft-state behavior without switching into learner delivery

## Common Navigation Pattern
1. Enter the authoring environment.
2. Open the intended project.
3. Confirm you are on project-level UI, not a delivery section.
4. Use the project structure or navigation controls to open a page.
5. Wait for the editor surface to finish loading before asserting editability.

## Key UI Landmarks
- project title or project overview heading
- page hierarchy, outline, or content tree
- editor canvas or editable content area
- authoring actions such as edit, preview, save, or publish

## What Usually Counts As Success
- the project overview loads without access or runtime errors
- a page opens in an editor rather than a learner-only reader view
- the visible page includes authoring controls or editable regions

## What Usually Counts As Failure
- access denied or redirect loops
- a learner delivery page opens instead of an editor
- the editor shell loads but the editable surface never appears
- blocking runtime errors, broken loading states, or missing project/page targets

## Authoring Smoke Interpretation
For shallow smoke cases, do not perform deep edits unless the step explicitly requires them. A stable smoke pass is usually about confirming:
- project access
- navigation into a page
- presence of an editable authoring surface
