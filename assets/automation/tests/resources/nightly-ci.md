# Nightly Playwright

From `assets/automation/`:

```sh
npm ci
npx playwright install --with-deps chrome
npx playwright test --config playwright.nightly.config.ts --grep @nightly
```

Tags are the only suite inventory. Existing test behavior, including missing-key skips, is preserved.
No separate environment or asset preflight is needed. The config retains Chrome, one worker and
one retry, and generates standard line/HTML reports without opening a browser report window.
Do not override reporters with `--reporter=line` in CI.

Configure Canvas's account/API/instructor/tool inputs as described in
`tests/torus/lti/canvas_playwright.md`, with `CANVAS_TOOL_LAUNCH_URL` and `TORUS_BASE_URL`
pointing at `PLAYWRIGHT_BASE_URL`. Its fixture needs dedicated `TORUS_ADMIN_EMAIL` and
`TORUS_ADMIN_PASSWORD`. Dot's parameter target must also use that origin; use its scenario
mode with service configuration `nightly-dot` so the test creates its own course and student.
Moodle's existing tagged tests require their dedicated fixtures and settings
from `tests/torus/lti_moodle/moodle_playwright.md`. Provision them to launch into nightly.

Keep traces/screenshots/video disabled. Standard reports still contain failure details and may
include page content; restrict report access and inspect artifacts before unattended launch.
Keep private asset/configuration downloads outside artifact upload paths. Retain existing fixture
cleanup, and maintain archives/answer keys together without changing them during active runs.

Nightly Playwright CI expects these environment variables:

- `CANVAS_UI_EMAIL`
- `CANVAS_UI_PASSWORD`
- `PLAYWRIGHT_BASE_URL`
- `PLAYWRIGHT_AUTOMATION_API_KEY`
- `PLAYWRIGHT_SCENARIO_TOKEN`
- `PLAYWRIGHT_CAPTCHA_TOKEN` (a separate secret matching the Playwright server; required for protected forms)

For GitHub Actions, store credentials as `nightly-ui` environment secrets. Store public
origins and integration identifiers as environment variables: `PLAYWRIGHT_BASE_URL`,
`TORUS_BASE_URL`, `CANVAS_BASE_URL`, `CANVAS_ACCOUNT_ID`, `CANVAS_INSTRUCTOR_USER_ID`,
`CANVAS_LTI_TOOL_NAME`, `CANVAS_TOOL_LAUNCH_URL`, `MOODLE_BASE_URL`,
`MOODLE_LTI_TOOL_NAME`, and `PLAYWRIGHT_PARAMETER_CONFIG_URL`. The workflow also passes
`CANVAS_API_TOKEN`, Canvas UI credentials, Moodle API/instructor/student credentials,
and Torus admin credentials from secrets. Moodle login “email” secrets contain the
usernames required by its existing helpers. Both Torus origins must be
`https://nightly-playwright.plasma.oli.cmu.edu`.

Use dedicated test accounts with the permissions required by each integration fixture.

Adaptive lesson tests that import private course archives also require the target Torus environment to have access to the Playwright assets bucket containing the referenced zip and answers JSON.

## Workflow rollout and launch

`Nightly Tests` runs daily at 05:17 UTC and accepts manual dispatch. Normal execution
builds and publishes one source revision, opens a signed record-only GitOps PR,
waits for accepted intent and matching public `/readyz` identity, then runs the
nightly config from that source SHA. Scheduled builds select current `master` after
acquiring the workflow lock. Manual dispatch and its reruns retain the dispatch SHA;
use a new dispatch to select a newer branch commit.

The workflow-level `nightly-playwright-plasma` lock covers build through finalization.
An active run finishes; a newer pending run can replace an older pending run. The
scenario job has no dependency on deployment or browser execution, but shares the
workflow's scheduling lock. Do not manually update the target, fixtures, or secrets
while a run is active.

For initial provisioning, dispatch with `publish_only: true` on a branch explicitly
allowed by `nightly-ui`. This publishes an image while skipping deployment, browser,
and scenario jobs. The default is false. Build and browser jobs use `nightly-ui`;
only deployment uses the App credentials in `nightly-deploy`. Both environments
must explicitly allow the reviewed feature branch for a full verification run.
Retain `master` access and exclude PR/fork access.

Phase 6's ordered feature-branch, operational, and launch checks are recorded in
`docs/exec-plans/current/nightly-playwright-ci/plan.md`. A successful manual run
must execute the intended integrations; inspect the standard report for configuration
skips. After all operational checks pass, merge normally and verify one scheduled
run from `master`. Remove temporary feature-branch environment allowances afterward.
Local fixtures do not establish hosted or deployed operational proof.

Provisioning and maintenance follow the internal nightly deployment runbook.
Recurring CI updates only the existing record's image and source metadata. The
updater and PR action restrict changes to the deployment record. GitHub enforces
merge rules. There is no preflight, previous-run PR scan, or direct-write fallback.

### Pause, resume, and cancellation

Phase 6 verification does not require a schedule pause. Keep the schedule unchanged,
check for active runs before dispatch, and coordinate verification around scheduled
execution. The optional maintenance procedure below is for an incident or deliberate
maintenance pause.

To pause scheduled execution, comment out the `schedule` trigger in
`.github/workflows/nightly-playwright.yml` on the default branch through normal review.
This pauses all scheduled jobs, including scenario tests. Keep `workflow_dispatch`
enabled for manual runs. Existing runs are not stopped by this change; wait for active
runs and finalization to finish before maintenance, and inspect pending runs as well.
Restore the `schedule` trigger through normal review to resume daily execution.

Cancel through the run's Actions page when necessary. The workflow requests an
immediate merge only; it never queues auto-merge. A failed or canceled run may leave
an open PR on `nightly-playwright/<run-id>-<attempt>`, which an operator can close
normally. If cancellation or a lost response coincides with the merge request, inspect
the PR to determine whether deployment intent changed. The failed run does not start
browser tests. Later runs do not scan earlier PRs.

For PRs left by an older workflow revision, disable any queued auto-merge before
closing them. Land the simplified Torus workflow and finish old runs before removing
the old GitOps lifecycle helper. Use a new manual dispatch to verify the replacement.

### Triage and retained diagnostics

Start with the run's stage summary: source/workflow SHAs, version, image tag/digest,
accepted GitOps commit, readiness result, and browser-step outcome. Readiness logs
show HTTP status and elapsed time, followed by the matched version/SHA on success;
raw HTTP bodies are not uploaded or printed. Matching public identity is an observation
before testing; it does not prove all-replica convergence, continuous identity, or
same-source image-digest identity.

- Build/push or dependency failure: no GitOps update occurs. Correct the build or
  registry problem before retrying; a later deployment failure can leave an unused image.
- Record/check/merge failure: inspect the GitOps PR and required checks. Resolve the
  conflict on a fresh validated PR/run; do not force-push or weaken branch rules.
- Readiness failure: inspect deployment/migration logs through normal operator access
  and compare the expected source/version. CI has no Kubernetes credentials. Browser
  execution remains skipped until the public identity matches.
- Browser failure or timeout: use the Playwright step outcome and available reports.
  Summary/upload success does not erase the failed step. Diagnose missing
  integration configuration even when existing tests report a skip.

Download `playwright-report` and `playwright-test-results` from the run's Artifacts
section or summary links. Retention is 14 days; the HTML report is not a hosted site.
Access follows repository Actions permissions. Verify those permissions and inspect
representative failures before unattended launch; masking log secrets does not sanitize
uploaded files. Keep traces/screenshots/video off and remove sensitive attachments if
inspection finds tokens, account links, private course content, or configuration data.
Uploads and summaries are best-effort after cancellation or runner loss.

### Failed-run data cleanup

Between runs, identify synthetic courses, users, sections, and LMS courses by their
run-specific names and the failing test's report. Retain existing test-owned cleanup;
Torus and QA maintainers remove only confirmed failed-run fixtures through supported
application/LMS operations. Dot scenario mode currently leaves its generated course,
student, and section for this operator cleanup. Preserve persistent integration
registrations, Moodle template/grade-passback courses, and private MinIO assets.
Never reset the nightly database or automatically reverse migrations. Each application
restart clears the instance-local mailbox; do not restart it during active tests.

## Parameterized Dot smoke test

The Dot chatbot smoke test is tagged `@nightly` and `@smoke`. Set
`PLAYWRIGHT_PARAMETER_CONFIG_URL` to an HTTP(S) URL containing a YAML document in this shape:

```yaml
target:
  base_url: 'https://deployment.example.edu'
  scenario_token: '<deployment scenario token>'

tests:
  dot_chatbot:
    setup:
      mode: 'scenario'
    course:
      project_name: 'dot_smoke_project_${RUN_ID}'
      project_title: 'Dot Smoke Project ${RUN_ID}'
      page_title: 'Dot Smoke Page'
      section_name: 'dot_smoke_section_${RUN_ID}'
      section_title: 'Dot Smoke Section ${RUN_ID}'
    student:
      name: 'dot_smoke_student_${RUN_ID}'
      email: 'dot-smoke-student-${RUN_ID}@example.edu'
      given_name: 'Dot'
      family_name: 'Student'
      password: '<dedicated smoke-test password>'
    dot:
      prompt: 'Reply with only the numeric answer: 1 + 1'
      response_timeout_ms: 120000
      service_config_name: 'deployment-dot-service'
```

The loader downloads and parses this file at run time, selects `tests.dot_chatbot`, and expands
`${RUN_ID}` before scenario seeding. Run only this smoke case with `npm run test-dot-smoke`.

The nightly deployment stores this document privately in the `torus-playwright-assets` bucket
under `dot_chatbot/config.yaml`, alongside the adaptive test assets. Set the GitHub `nightly-ui`
environment variable `PLAYWRIGHT_PARAMETER_CONFIG_URL` to
`https://nightly-playwright.plasma.oli.cmu.edu/test/assets/dot_chatbot/config.yaml`.
This uses the existing Torus `/test/assets/*path` route to retrieve the single MinIO object;
the same route already serves adaptive test assets.
The document uses scenario mode and the `nightly-dot` service; the test creates its course and
student when it runs. It contains the deployment scenario token and a dedicated test password,
so keep its contents out of the repository and logs. Update the stored document when rotating
the scenario token.

For `/test/assets/` URLs on the runner's configured Torus origin (`PLAYWRIGHT_BASE_URL`, or a
runtime override), the loader sends `x-playwright-scenario-token` using the runner's existing
scenario token. Authenticated downloads reject redirects to prevent forwarding this credential.
Other HTTP(S) configuration URLs continue to work without adding the scenario token.

For deployments where the scenario bootstrap endpoint is unavailable, use an existing enrolled
student and section instead. `target.scenario_token`, the project fields, section name/title, and
service configuration are not required in this mode:

```yaml
target:
  base_url: 'https://deployment.example.edu'

tests:
  dot_chatbot:
    setup:
      mode: 'existing'
    course:
      page_title: 'Dot Smoke Page'
      section_slug: '<existing section slug>'
    student:
      name: 'dot_smoke_student'
      email: '<existing enrolled student email>'
      given_name: 'Dot'
      family_name: 'Student'
      password: '<dedicated smoke-test password>'
    dot:
      prompt: 'Reply with only the numeric answer: 1 + 1'
      response_timeout_ms: 120000
```

The Dot suite disables Playwright tracing because traces can retain configuration downloads,
scenario request bodies, and login credentials. The nightly configuration URL contains no
credentials and belongs in a CI environment variable; keep authentication tokens in CI secrets
and the configuration document in private storage. Limit the document to dedicated low-privilege
smoke users. Other deployments using URLs with embedded credentials must keep those URLs secret.
