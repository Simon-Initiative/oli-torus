# Platform Features

## ✅ Verifier Utility

We use a [Verifier](src/core/verify/Verifier.ts) helper to simplify Playwright assertions and make tests more readable.

### 📋 Available Methods

| Method                           | Description                                                                   | Example                                                        |
| :------------------------------- | :---------------------------------------------------------------------------- | :------------------------------------------------------------- |
| `expectIsVisible(locator)`       | Ensures that the element is visible on the page.                              | await Verifier.expectIsVisible(page.locator('#btn-save'));     |
| `expectHasText(locator, text)`   | Ensures that the element’s text matches the expected value (string or regex). | await Verifier.expectHasText(page.locator('h1'), 'Welcome');   |
| `expectHasClass(locator, class)` | Ensures that the element contains the given CSS class.                        | await Verifier.expectHasClass(page.locator('.btn'), 'active'); |

🎯 Benefits

- Cleaner and more readable test code.
- Consistent error messages across the suite.
- Easy to extend with new assertions when needed.

## ⏳ Waiter

The [Waiter](src/core/wait/Waiter.ts) class centralizes the possible waits we can perform on user interface elements.

### 📋 Available Methods

| Method                             | Description                                                                                   | Parameters                                                                                                                                                                | Example                                                     |
| :--------------------------------- | :-------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------- |
| `waitForLoadState(page, state)`    | Pauses execution until the page reaches a specific load state. Useful for initial navigation. | `page`: The Playwright Page object. <br> `state?`: `'load'`, `'domcontentloaded'` (default), or `'networkidle'`.                                                          | `await Waiter.waitForLoadState(page, 'load');`              |
| `waitFor(locator, state, timeout)` | Waits for a specific condition on a given element locator.                                    | `locator`: The target element. <br> `state`: The condition: `'attached'`, `'detached'`, `'visible'`, or `'hidden'`. <br> `timeout?`: Max wait time in ms (default: 5000). | `await Waiter.waitFor(page.locator('#modal'), 'detached');` |

---

🎯 Benefits

- **Flaky Test Reduction:** Standardizes reliable waiting, minimizing failures caused by timing issues.
- **Clarity:** Replaces raw Playwright `await page.waitFor...` calls with clear, intent-driven static methods.
- **Maintainability:** Simplifies timeouts and common waiting patterns across the entire test suite.

## 🧰 Visual Studio Code tools

With this plugin we can:

- pick a locator
- record a new test
- select the browser to execute the tests
- select the settings to apply in to the tests
