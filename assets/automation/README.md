# WW-TORUS-E2E

This platform contains the automated e2e tests.

## 🔑 Runtime configuration (no .env files)

- Playwright config reads `PLAYWRIGHT_BASE_URL` for `baseURL`; when the variable is not present it defaults to `http://localhost`.
- Each spec defines its own runtime login data (emails, passwords, names) and seeds its own YAML scenario in `beforeAll`, using a per-run `RUN_ID` to avoid collisions.
- Scenario seeding is authenticated with a default token of `my-token`; change this in the spec runtime config and in your Phoenix `PLAYWRIGHT_SCENARIO_TOKEN` if needed.
- Browser auto-close behavior is controlled by runtime config in specs (defaults to keep the browser open between tests).
- The nightly LTI spec reads `CANVAS_UI_EMAIL` and `CANVAS_UI_PASSWORD` from the environment instead of hardcoding credentials.
- The live OAuth login spec reads its target, dedicated accounts, provider UI selectors, and expected Torus destinations from the remote YAML selected by `PLAYWRIGHT_PARAMETER_CONFIG_URL`.
- GitHub Actions wiring for the nightly run lives in `.github/workflows/nightly-playwright.yml` and expects those values as environment secrets on the `nightly-ui` environment.

## 🧪 Configuration Tests & Report

Install dependencies

```bash
npm i
```

Run the configuration for testing

```bash
npm run test-config
```

Run it in headed mode (visible browser)

```bash
npm run test-config:headed
```

Open the latest Playwright HTML report

```bash
npm run show-report
```

### Live OAuth login smoke tests

The OAuth suite exercises the complete provider redirect for one learner and one author account. It runs headed Chrome because Google rejects the automated headless sign-in browser. It does not save authenticated storage state, and tracing is disabled because OAuth traces can expose credentials, session cookies, or authorization response data.

Host the following YAML in a secret-protected location and point `PLAYWRIGHT_PARAMETER_CONFIG_URL` at it. Do not commit real account credentials or this runtime configuration to the repository.

```yaml
target:
  base_url: https://torus.example.test
tests:
  oauth_logins:
    timeout_ms: 120000
    provider:
      name: Google
      authorization_hostname: accounts.google.com
      selectors:
        email_input: 'input[name="identifier"], input#identifierId, input[aria-label="Email or phone"]'
        email_submit: '#identifierNext'
        password_input: 'input[type="password"]:not([aria-hidden="true"]):not([name="hiddenPassword"])'
        password_submit: '#passwordNext'
        consent_submit: 'button:has-text("Continue")'
        error_message: 'text=/couldn.t find this account|wrong password|browser or app may not be secure|couldn.t sign you in/i'
    accounts:
      learner:
        email: dedicated-learner@example.test
        password: replace-at-runtime
        torus_account_name: OAuth Learner
        login_path: /users/log_in
        authorization_path: /users/auth/google/new
        callback_path: /users/auth/google/callback
        landing_path: /workspaces/student
        workspace_heading: Courses available
        account_settings_link_name: Account Settings
        account_settings_path: /users/settings
        logout_path: /
      author:
        email: dedicated-author@example.test
        password: replace-at-runtime
        torus_account_name: OAuth Author
        login_path: /authors/log_in
        authorization_path: /authors/auth/google/new
        callback_path: /authors/auth/google/callback
        landing_path: /workspaces/course_author
        workspace_heading: Course Author
        account_settings_link_name: Edit Account
        account_settings_path: /authors/settings
        account_label: Author
        logout_path: /authors/log_in
```

The dedicated provider accounts must already be linked to the corresponding Torus account class and configured without MFA, CAPTCHA, recovery, or other interactive challenges. Keep them least-privileged and isolated from production data. Omit `consent_submit` only when consent has already been granted and the provider never renders that step.

```bash
PLAYWRIGHT_PARAMETER_CONFIG_URL=https://config.example.test/oauth.yaml npm run test-oauth-logins
```

## 🤖 Automated Configurations

These configurations are executed **before running the tests** and are already automated.
The following processes are included.

### 📁 Project Creation

Course authoring scenarios create projects with names suffixed by the current `RUN_ID` (e.g., `TQA-10-automation-1700000000000`).

### 🎨 Multimedia File Configuration

The upload of multimedia resources is automated for the following projects (names include the `RUN_ID` suffix):

| 📂 Project Name            | 📄 File Name            | 🏷️ Type |
| :------------------------- | :---------------------- | :------ |
| TQA-12-automation${RUN_ID} | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation${RUN_ID} | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation${RUN_ID} | audio-test-01.mp3       | audio   |
| TQA-13-automation${RUN_ID} | video-test-01.mp4       | video   |

### 📚 Bibliography

| 📂 Project Name            | 🏷️ Type                                                                                                                                                                                                                                   |
| :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TQA-13-automation${RUN_ID} | `@book{Newton2015Philosophiae, address = {Garsington, England}, author = {Newton, Isaac}, year = {2015}, month = {5}, publisher = {Benediction Classics}, title = {Philosophiae {Naturalis} {Principia} {Mathematica} ({Latin},1687)}, }` |

## 🧩 Platform Features

[View the features](PLATFORM_FEATURES.md)
