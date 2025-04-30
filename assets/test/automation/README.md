# WW-ARGOS-E2E

This platform has the automation test end to end of de system Argos.

## Prepare environment

```bash
git clone https://github.com/Clientes-CES/ww-argos-e2e
```

```bash
cd ww-argos-e2e
```

```bash
npm i
```

```bash
npx playwright install
```

## Execute tests

Runs the end-to-end tests.

```bash
npm run test
```

Starts the interactive UI mode.

```bash
npm run test-ui
```

Runs the tests only on Desktop Chrome.

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
  |-->core
  |-->systems
--test
  |-->argos
```
