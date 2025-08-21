# WW-TORUS-E2E

This platform contains the automated e2e tests.

## Execute tests

Runs the end-to-end tests.

```bash
npm run test
```

Starts the interactive UI mode.

```bash
npm run test-ui
```

Runs the tests only on Desktop Chromium.

```bash
npm run test-chromium
```

Runs the tests in debug mode.

```bash
npm run test-debug
```

Auto generate tests with Codegen.

```bash
npm run codegen
```

Show the tests report

```bash
npm run show-report
```

## Visual Studio Code tools

[Playwright Test for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright)

Withd this plugin we can:

- pick a locator
- record a new test
- select the browser to execute the tests
- select the settings to apply in to the tests

## Project structure

```code
--src
  |--> core
  |--> systems
--test
  |--> resources
  |--> torus
```

## Required environment variables

Before running the tests, make sure you configure the following environment variables in a .env file. These are required for authenticating the users and accessing the platform.

```env
BASE_URL=https://your-url.com
EMAIL_AUTHOR=your_author_email@example.com
PASS_AUTHOR=your_author_password
EMAIL_STUDENT=your_student_email@example.com
PASS_STUDENT=your_student_password
NAME_STUDENT=Your Student Name
EMAIL_INSTRUCTOR=your_instructor_email@example.com
PASS_INSTRUCTOR=your_instructor_password
EMAIL_ADMIN=your_admin_email@example.com
PASS_ADMIN=your_admin_password

```

## Pre-conditions for `user-accounts` suite

To successfully run the `user-accounts` test suite, make sure the following conditions are met:

### ✅ General requirements for `user-accounts`

- All required environment variables listed in the `.env` file must be set (see [Required environment variables](#required-environment-variables)).
- Playwright must be installed and configured.
- The `loginData` used in this suite must be correctly set up with valid credentials for each role.

## Pre-conditions for `course-authoring` suite

To successfully run the `course-authoring` test suite, make sure the following conditions are met:

### ✅ General requirements for `course-authoring`

- All required environment variables listed in the `.env` file must be set (see [Required environment variables](#required-environment-variables)).
- The test data used in this suite assumes that specific projects already exist on the platform with fixed IDs

### 🧪 Test data setup

Before running this suite, verify that:

- The **author** user has access to projects with the following IDs:
  - `tqa10automation`
  - `tqa11automation`
  - `tqa12automation` must have `img-mock-05-16-2025.jpg`
  - `tqa13automation` must have `img-mock-05-16-2025.jpg` `audio-test-01.mp3` `video-test-01.mp4`
  - `tqa14automation`
  - `tqa15automation`
- The above projects should exist on the platform. Some tests depend on navigating directly to those project URLs.
- The **media files** used in tests must be uploaded and available in the media library. These include:
  - `img-mock-05-16-2025.jpg`
  - `audio-test-01.mp3`
  - `video-test-01.mp4`
