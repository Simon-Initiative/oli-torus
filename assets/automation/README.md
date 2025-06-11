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
