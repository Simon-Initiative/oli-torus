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

With this plugin we can:

- pick a locator
- record a new test
- select the browser to execute the tests
- select the settings to apply in to the tests

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
