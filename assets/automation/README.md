# WW-TORUS-E2E

This platform contains the automated e2e tests.

## 🔑 Runtime configuration (no .env files)

- Playwright config uses a fixed `baseURL` of `http://localhost` (see `playwright.config.ts`). Adjust there if you target another host.
- Each spec defines its own runtime login data (emails, passwords, names) and seeds its own YAML scenario in `beforeAll`, using a per-run `RUN_ID` to avoid collisions.
- Scenario seeding is authenticated with a default token of `my-token`; change this in the spec runtime config and in your Phoenix `PLAYWRIGHT_SCENARIO_TOKEN` if needed.
- Browser auto-close behavior is controlled by runtime config in specs (defaults to keep the browser open between tests).
- The nightly LTI spec reads `CANVAS_UI_EMAIL` and `CANVAS_UI_PASSWORD` from the environment instead of hardcoding credentials.
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
