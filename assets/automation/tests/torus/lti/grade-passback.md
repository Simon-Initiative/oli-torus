# Grade Passback Test

This document covers `grade-passback.spec.ts`, the Playwright scenario that verifies Tokamak passes a graded page score back to the Canvas gradebook.

## What The Test Does

The test:

1. Logs in to Canvas as the student.
2. Resolves the student display name from Canvas after login.
3. Opens the LTI launch link.
4. Navigates to the graded page.
5. Starts or resumes the attempt if needed.
6. Submits the student response.
7. Logs in to Canvas as the instructor.
8. Polls the gradebook until the passed-back score appears.

The student name is not hardcoded. It is read from Canvas through the authenticated browser session.

## Required Environment Variables

Set these variables in the environment where Playwright runs:

- `CANVAS_STUDENT_EMAIL`
- `CANVAS_STUDENT_PASSWORD`
- `CANVAS_ADMIN_EMAIL` or `CANVAS_INSTRUCTOR_EMAIL`
- `CANVAS_ADMIN_PASSWORD` or `CANVAS_INSTRUCTOR_PASSWORD`

Optional:

- `CANVAS_LTI_TOOL_NAME`

If `CANVAS_LTI_TOOL_NAME` is not set, the test uses `OLI Torus (tokamak)`.

No API key is required. The test reads the student name from the authenticated Canvas browser session after login.

## Canvas Prerequisites

The Canvas environment must already have:

- The course `Playwright Test Course`
- The `OLI Torus (tokamak)` module item link inside the course modules page
- The graded page `Graded page for graded passback`
- A student account enrolled in the course
- An instructor or admin account with access to the course gradebook

The test expects the graded page to be available and configured for grade passback.

## How To Run

Run the test from `assets/automation`:

```bash
npx playwright test tests/torus/lti/grade-passback.spec.ts
```

## Behavior Notes

- If the graded page already has an attempt in progress, the test resumes it instead of failing.
- If the gradebook is still loading, the test waits and retries until the score appears or the timeout is reached.
- The gradebook polling timeout is 3 minutes.

## Troubleshooting

- If the test fails before login, verify the Canvas credentials and the required environment variables.
- If the student name lookup fails, verify the student account can log in successfully and reach `/api/v1/users/self`.
- If the score never appears in the instructor gradebook, verify the activity is configured for passback and that Canvas has time to process the result.
