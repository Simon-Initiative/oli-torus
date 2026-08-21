# WW-TORUS-E2E

This platform contains the automated e2e tests.

## 🔑 Runtime configuration (no .env files)

- Playwright config reads `PLAYWRIGHT_BASE_URL` for `baseURL`; when the variable is not present it defaults to `http://localhost`.
- Each spec defines its own runtime login data (emails, passwords, names) and seeds its own YAML scenario in `beforeAll`, using a per-run `RUN_ID` to avoid collisions.
- Scenario seeding is authenticated with a default token of `my-token`; change this in the spec runtime config and in your Phoenix `PLAYWRIGHT_SCENARIO_TOKEN` if needed.
- Browser auto-close behavior is controlled by runtime config in specs (defaults to keep the browser open between tests).
- The nightly LTI spec reads `CANVAS_UI_EMAIL` and `CANVAS_UI_PASSWORD` from the environment instead of hardcoding credentials.
- The live OAuth login spec reads its target, operation timeout, and dedicated accounts from the remote YAML selected by `PLAYWRIGHT_PARAMETER_CONFIG_URL`.
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

The Google selectors and expected Torus routes and copy are stable test constants. The runtime YAML contains only values that vary by environment or account. `timeout_ms` is the timeout for each external operation; the complete test receives three times that budget.

Host the YAML in a secret-protected location and point `PLAYWRIGHT_PARAMETER_CONFIG_URL` at it. Do not commit real account credentials or this runtime configuration to the repository.

```yaml
target:
  base_url: https://torus.example.test
tests:
  oauth_logins:
    timeout_ms: 120000
    accounts:
      learner:
        email: REPLACE_WITH_LEARNER_GOOGLE_EMAIL
        password: REPLACE_WITH_LEARNER_GOOGLE_PASSWORD
      author:
        email: REPLACE_WITH_AUTHOR_GOOGLE_EMAIL
        password: REPLACE_WITH_AUTHOR_GOOGLE_PASSWORD
        account_label: Author
```

The dedicated provider accounts must be linked to the corresponding Torus account class and configured without MFA, CAPTCHA, recovery, or other interactive challenges. If Google displays the “Verify it’s you” page, the test aborts with a message explaining that the account must have 2FA disabled. Keep the accounts least-privileged and isolated from production data.

#### One-time automation setup

From the repository root:

```bash
cd assets/automation
npm install
npx playwright install --with-deps chrome
```

#### Running locally

1. Configure a Google OAuth web client with these authorized redirect URIs:

   ```text
   http://localhost/users/auth/google/callback
   http://localhost/authors/auth/google/callback
   ```

2. Start or restart Torus from the repository root with `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` set.
3. Log in once manually with each dedicated account through `http://localhost/users/log_in` and `http://localhost/authors/log_in`. This creates and links the corresponding learner and author records.
4. Save the YAML above as `/tmp/oauth-local.yaml`, set `target.base_url` to `http://localhost`, and replace all credential placeholders.
5. Serve the YAML from a separate terminal:

   ```bash
   python3 -m http.server 8787 --bind 127.0.0.1 --directory /tmp
   ```

6. From `assets/automation`, run:

   ```bash
   PLAYWRIGHT_PARAMETER_CONFIG_URL=http://127.0.0.1:8787/oauth-local.yaml npm run test-oauth-logins
   ```

#### Running against an already-deployed environment

1. Log in once manually with each dedicated account through the environment's learner and author login pages so Torus creates and links both account classes.
2. Create a YAML file from the example above using that environment's base URL and dedicated credentials.
3. Host it at a private HTTP(S) URL. For a quick run from your machine, use the loopback server shown in the local instructions.
4. From `assets/automation`, run the suite with the URL of that YAML file.

Tokamak example:

```yaml
target:
  base_url: https://tokamak.oli.cmu.edu
```

```bash
PLAYWRIGHT_PARAMETER_CONFIG_URL=http://127.0.0.1:8787/oauth-tokamak.yaml npm run test-oauth-logins
```

Stellarator example:

```yaml
target:
  base_url: https://stellarator.oli.cmu.edu
```

```bash
PLAYWRIGHT_PARAMETER_CONFIG_URL=http://127.0.0.1:8787/oauth-stellarator.yaml npm run test-oauth-logins
```

To target another staging or production deployment, change the base URL and use dedicated accounts linked in that environment. A real Chrome window opens and runs both account-class flows.

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
