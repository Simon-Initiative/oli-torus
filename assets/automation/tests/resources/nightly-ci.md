Nightly Playwright CI expects these environment variables:

- `CANVAS_UI_EMAIL`
- `CANVAS_UI_PASSWORD`

For GitHub Actions, store them as environment secrets on the `nightly-ui` environment, then reference that environment from `.github/workflows/nightly-playwright.yml`.

Keep these credentials scoped to dedicated low-privilege test accounts.

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
