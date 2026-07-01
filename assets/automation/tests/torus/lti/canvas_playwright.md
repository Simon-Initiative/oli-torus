# Canvas Playwright LTI Notes

This note preserves the working assumptions for the Torus Canvas LTI launch
automation. It is intentionally free of real credentials and should be updated
when the Canvas setup or launch flow changes.

Last updated on May 28, 2026.

## Current Test

The current LTI spec is `assets/automation/tests/torus/lti/launch.spec.ts`.

It creates an isolated Torus source project and isolated Canvas state for each
run, launches Tokamak through Canvas, creates a Torus LTI section from the
first-launch setup wizard, deletes that Torus section from the manage page,
deletes the temporary Canvas course, and then deletes the temporary Torus
source project.

The default temporary Torus source project title is:

- `LTI_CANVAS_TEST lti-<timestamp>`

The generated Canvas course name is:

- `LTI_CANVAS_TEST lti-<timestamp>`

The generated Torus section name is:

- `LTI_CANVAS_TEST lti-<timestamp>`

The generated Torus section number is:

- `lti-<timestamp>`

Canvas and Torus source-project cleanup are handled by the spec. Successful
runs also delete the Torus section from the manage page before deleting the
temporary Canvas course.

## Required Local Environment

Do not commit real Canvas credentials or API tokens.

The spec requires these local environment variables:

- `CANVAS_INSTRUCTOR_EMAIL`
- `CANVAS_INSTRUCTOR_PASSWORD`
- `CANVAS_ACCOUNT_ID`
- `CANVAS_API_TOKEN`
- `TORUS_ADMIN_EMAIL`
- `TORUS_ADMIN_PASSWORD`

Recommended:

- `CANVAS_INSTRUCTOR_USER_ID`, used to enroll the dedicated Canvas test
  instructor as a teacher in the generated course before launching the tool.

The spec still accepts the older `CANVAS_UI_EMAIL` and `CANVAS_UI_PASSWORD`
names as fallbacks during migration.

Optional overrides:

- `CANVAS_BASE_URL`, default `https://canvas.oli.cmu.edu`
- `CANVAS_LTI_TOOL_NAME`, default `OLI Torus (tokamak)`
- `CANVAS_TOOL_LAUNCH_URL`, default `https://tokamak.oli.cmu.edu/lti/launch`
- `TORUS_BASE_URL`, default is derived from `CANVAS_TOOL_LAUNCH_URL`
- `TORUS_LTI_PROJECT_TITLE`, default `LTI_CANVAS_TEST lti-<timestamp>`

The spec still accepts the older `CANVAS_TOOL_NAME` name as a fallback during
migration.

As of May 28, 2026, the local Canvas API env values were validated without
printing the token:

- `CANVAS_BASE_URL` points at `https://canvas.oli.cmu.edu`.
- `CANVAS_ACCOUNT_ID` is `1`.
- The account API identifies account `1` as `Open Learning Initiative`.
- The token can read account courses.
- The token reports `manage_courses: true`, `manage_account_settings: true`,
  and `manage_developer_keys: true`.

## Canvas API Provisioning

The spec uses the Torus UI and Canvas API to avoid relying on a pre-existing
Torus source project or Canvas course. For each run it:

1. Logs into the target Torus instance as the configured Torus admin.
2. Creates a temporary Torus project.
3. Adds a basic unscored practice page.
4. Publishes the project.
5. Sets project publishing visibility to `Open`.
6. Creates a course in the configured Canvas account.
7. Enrolls `CANVAS_INSTRUCTOR_USER_ID` as a teacher when configured.
8. Creates a module named `Torus LTI Launch`.
9. Creates an external tool module item for `OLI Torus (tokamak)`.
10. Publishes the module.
11. Publishes the module item.
12. Launches the tool from the Canvas UI as the configured instructor.
13. Deletes the Torus section from the manage page.
14. Deletes the temporary Canvas course in a `finally` block.
15. Deletes the temporary Torus source project in a `finally` block.

Read-only API inspection of the historical fixed course showed:

- Account-level external tool id `68` is `OLI Torus (tokamak)`.
- Tool launch URL is `https://tokamak.oli.cmu.edu/lti/launch`.
- Course `682` has module `437`.
- Module item `917` is type `ExternalTool`, content id `68`, published, and
  configured with `new_tab: true`.

A write smoke test confirmed that Canvas accepts this provisioning flow:

1. `POST /api/v1/accounts/:account_id/courses`
2. `POST /api/v1/courses/:course_id/modules`
3. `POST /api/v1/courses/:course_id/modules/:module_id/items`
4. `PUT /api/v1/courses/:course_id/modules/:module_id` with
   `module[published]=true`
5. `PUT /api/v1/courses/:course_id/modules/:module_id/items/:item_id` with
   `module_item[published]=true`

Canvas did not publish the module and item when `published=true` was sent only
during creation, so the follow-up `PUT` requests are required.

## Torus First-Launch Section Creation

A disposable Canvas course launch was inspected on May 28, 2026. After Canvas
launched `OLI Torus (tokamak)` for a new Canvas course with no existing Torus
section, Torus redirected to:

- `/sections/new/:context_id`

The visible UI was the `New course set up` stepper with:

- Step 1: `Select your source materials`
- Step 2: `Name your course`
- Step 3: `Course details`

The first step is headed `Select source` and shows `Select Curriculum`, a search
box, card/list view controls, pagination, and source cards. The `Next step`
button is disabled until a source is selected.

The source list comes from `Publishing.retrieve_visible_sources(user,
institution)` for LTI launches. Source rows are either:

- `publication:<id>` for a published project source
- `product:<id>` for a template/product source

The current selectors rely on:

- `iframe[name="tool_content"]` when Canvas embeds the launch.
- The visible `Load OLI Torus (tokamak) in a new window` button when Canvas
  requires a popup/new tab launch.
- Torus search placeholder `Search...`.
- Search result summary text `Results filtered on "<source title>"`.
- Source card links with `.course-card-link`.
- Wizard fields `#section_title`, `#section_course_section_number`,
  `#section_start_date`, `#section_end_date`, and
  `#section_preferred_scheduling_time`.
- The modality label `Never, it's a self paced course`.
- Final redirect to `/sections/:section_slug/manage`.
- Manage page cleanup button `Delete Section`.
- Delete confirmation modal `#delete_section_modal`.
- Delete confirmation button `Delete this section`.
- After deletion, Tokamak may redirect to `/sections` or back to
  `/sections/new/:context_id` for the same LTI context.

After selecting a source, the stepper collects the course name, course section
number, modality, dates, and schedule details. Creating the section calls
`Delivery.create_section(changeset, source, current_user, section_spec)`, where
`section_spec` is an LTI section specification built from the latest LTI params
for the launched Canvas context.

## Historical Fixed Course

The old version of this test used a fixed Canvas course and pre-existing Torus
section. These details are retained only as debugging context:

- Canvas course: `Second Test Second`
- Canvas course path: `/courses/682`
- Canvas module item path: `/courses/682/modules/items/917`
- Tool link text: `OLI Torus (tokamak)`
- The popup reached Torus at `/sections/second_test_second_w49b5/manage`.
- The Torus section details page showed:
  - Course Section ID `second_test_second_w49b5`
  - Course Section Type `LTI`
  - Institution `OLI Test Canvas testing`
  - Instructor `Instructor, Dovid Playwright`

Treat these ids and slugs as fixture details, not stable test design.

## What To Inspect When Updating Selectors

Codex does not automatically see the user's browser. To understand the current
Canvas or Torus interface, inspect Playwright outputs from a local run:

- `assets/automation/test-results/**/trace.zip`
- `assets/automation/test-results/**/*.png`
- `assets/automation/playwright-report/index.html`
- Playwright locator errors and action logs
- DOM or accessibility snapshots captured during debugging

Prefer stable selectors in this order:

- Accessible roles and names (`getByRole`, `getByLabel`, visible link names).
- Stable frame names such as `iframe[name="tool_content"]`.
- Stable app-controlled attributes, if present.
- CSS or generated Canvas ids only when no better selector exists.

## Run Command

From `assets/automation`:

```bash
npm run pw -- tests/torus/lti/launch.spec.ts --project "Google Chrome"
```

If using a local env file from the repository root:

```bash
set -a
source ../../oli.env
set +a
npm run pw -- tests/torus/lti/launch.spec.ts --project "Google Chrome"
```

Do not paste command output that includes credentials into tickets, docs, or PR
comments.
