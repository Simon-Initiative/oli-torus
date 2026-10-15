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

For GitHub Actions, store them as environment secrets on the `nightly-ui` environment, then reference that environment from `.github/workflows/nightly-playwright.yml`.

Use dedicated test accounts with the permissions required by each integration fixture.

Adaptive lesson tests that import private course archives also require the target Torus environment to have access to the Playwright assets bucket containing the referenced zip and answers JSON.

## Workflow rollout and launch

For initial provisioning, manually dispatch `Nightly Tests` on the reviewed source
branch with `publish_only: true`. The branch must be allowed by `nightly-ui`.
This publishes the image and records its tag, digest, source SHA, and version in the
build job summary while skipping browser and scenario tests. It does not deploy the
image or prove test readiness. The option defaults to false; scheduled runs and normal
manual runs retain both test jobs. Once Phase 6 adds deployment, that job must also
skip publish-only runs.

The current workflow builds the Playwright image and checks out that source SHA for
browser tests. Phase 6 still needs to connect GitOps deployment and public readiness,
then use the nightly config command above instead of the current reporter override.
The deployment job uses one App in `nightly-deploy` for PR operations and cleanup.
There is no separate GitOps preflight or scan for prior runs' PRs. Build and browser
jobs have no GitOps credentials. Operators handle orphaned PRs after interrupted runs;
a blocked deployment may leave an unused image.
Retain existing test setup and skip behavior; add no separate asset/configuration check.

The Phase 6 launch checklist in Torus
`docs/exec-plans/current/nightly-playwright-ci/plan.md` includes one full manual run,
report access/privacy inspection, actual failure/cancellation/concurrency checks, and
one successful scheduled run. Inspect standard reports to confirm intended integrations
execute; missing-configuration skips do not prove launch readiness. Reuse earlier valid
component evidence instead of repeating unchanged tests. Phase 6 now includes the launch
work formerly assigned to Phase 7.

Provisioning and manual deployment maintenance follow
`docs/handbook/runbooks/nightly-playwright.md` in `oli-torus-gitops`. Keep unattended
execution gated on provisioning and the manual/artifact checks; Phase 6 will document
how to pause scheduled browser runs while retaining manual verification and the
independent scenario job. No schedule or remote policy changes are made by this runbook.

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
