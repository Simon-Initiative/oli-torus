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
`TORUS_ADMIN_PASSWORD`. Dot's parameter target must also use that origin; use its existing-fixture
mode for nightly. Moodle's existing tagged tests require their dedicated fixtures and settings
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
scenario request bodies, and login credentials. Store the configuration URL and credentials in
protected CI secrets and limit the configuration document to dedicated low-privilege smoke users.
