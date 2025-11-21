# WW-TORUS-E2E

This platform contains the automated e2e tests.

## 🔑 Required environment variables

### 📄 login.env

Before running the tests, make sure you configure the following environment variables in a .env file, which must be located at `tests/resources/login.env` These are required for authenticating the users and accessing the platform.

```env
BASE_URL=https://your-url.com

EMAIL_AUTHOR=your_author_email@example.com
PASS_AUTHOR=your_author_password

EMAIL_STUDENT=your_student_email@example.com
PASS_STUDENT=your_student_password
NAME_STUDENT=Your Student Name
LASTNAME_STUDENT=Your Student last name

EMAIL_INSTRUCTOR=your_instructor_email@example.com
PASS_INSTRUCTOR=your_instructor_password

EMAIL_ADMIN=your_admin_email@example.com
PASS_ADMIN=your_admin_password
SCENARIO_TOKEN=shared_secret_string
```

### config.env

This file is located in `tests/resources/config.env`

| Name                 | Accepted values | Description                                                                                                     |
| -------------------- | --------------- | --------------------------------------------------------------------------------------------------------------- |
| `AUTO_CLOSE_BROWSER` | `true`, `false` | Closes the browser automatically after the run. Set to `false` to keep it open for debugging between test runs. |

### 🔐 Scenario endpoint token

The Phoenix server must expose the Playwright scenario endpoint only in non-production environments. Set `PLAYWRIGHT_SCENARIO_TOKEN` (e.g., in `dev.env`) to a secret string and export the matching value to the `SCENARIO_TOKEN` entry in `tests/resources/login.env`. This shared secret authenticates `POST /test/scenario-yaml` calls that seed base data for tests.

When running the backend locally, ensure `mix phx.server` starts with `PLAYWRIGHT_SCENARIO_TOKEN` defined (e.g., `PLAYWRIGHT_SCENARIO_TOKEN=local-secret mix phx.server`).

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

The following projects are automatically created with these names:

- `TQA-10-automation`
- `TQA-11-automation`
- `TQA-12-automation`
- `TQA-13-automation`
- `TQA-14-automation`
- `TQA-15-automation`
- `TQA-17-automation`

### 🎨 Multimedia File Configuration

The upload of multimedia resources is automated for the following projects:

| 📂 Project Name   | 📄 File Name            | 🏷️ Type |
| :---------------- | :---------------------- | :------ |
| TQA-12-automation | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation | audio-test-01.mp3       | audio   |
| TQA-13-automation | video-test-01.mp4       | video   |

### 📚 Bibliography

| 📂 Project Name   | 🏷️ Type                                                                                                                                                                                                                                   |
| :---------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TQA-13-automation | `@book{Newton2015Philosophiae, address = {Garsington, England}, author = {Newton, Isaac}, year = {2015}, month = {5}, publisher = {Benediction Classics}, title = {Philosophiae {Naturalis} {Principia} {Mathematica} ({Latin},1687)}, }` |

## 🧩 Platform Features

[View the features](PLATFORM_FEATURES.md)
