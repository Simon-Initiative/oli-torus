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

## 🧪 Automated Configurations

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

| 📂 Project Name    | 📄 File Name             | 🏷️ Type |
| :----------------- | :----------------------- | :------ |
| TQA-12-automation  | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation  | img-mock-05-16-2025.jpg | image   |
| TQA-13-automation  | audio-test-01.mp3       | audio   |
| TQA-13-automation  | video-test-01.mp4       | video   |
