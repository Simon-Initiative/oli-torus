import { expect, Locator, Page } from '@playwright/test';

export class Verifier {
  /**
   * Checks if the given locator is visible on the page.
   * @param locator - The Playwright locator to check.
   * @param description - A description of the element for error messages.
   */
  static async expectIsVisible(locator: Locator, description = 'Should be visible.') {
    await expect(locator, description).toBeVisible();
  }

  /**
   * Checks if the given locator is hidden on the page.
   * @param locator - The Playwright locator to check.
   * @param description - A description of the element for error messages.
   */
  static async expectIsHidden(locator: Locator, description = 'Should be hidden.') {
    await expect(locator, description).toBeHidden();
  }

  /**
   * Checks if the given locator has the expected text.
   * @param locator - The Playwright locator to check.
   * @param expectedText - The text to match.
   * @param description - A description of the element for error messages.
   */
  static async expectHasText(
    locator: Locator,
    expectedText: string | RegExp,
    description = 'Should have text:',
  ) {
    await expect(locator, `[${description}] "${expectedText}"`).toHaveText(expectedText);
  }

  /**
   * Checks if the given locator contains the expected text.
   * @param locator - The Playwright locator to check.
   * @param expectedText - The text to contain.
   * @param description - A description of the element for error messages.
   */
  static async expectContainText(
    locator: Locator,
    expectedText: string | RegExp,
    description = 'Should contain text:',
  ) {
    await expect(locator, `[${description}] "${expectedText}"`).toContainText(expectedText);
  }

  /**
   * Checks if the given locator has the expected CSS class.
   * @param locator - The Playwright locator to check.
   * @param expectedClass - The CSS class that should be present.
   * @param description - A description of the element for error messages.
   */
  static async expectHasClass(
    locator: Locator,
    expectedClass: string,
    description = 'Should have class:',
  ) {
    await expect(locator, `[${description}] "${expectedClass}"`).toHaveClass(
      new RegExp(`\\b${expectedClass}\\b`),
    );
  }

  /**
   * Checks if the given locator does NOT have the specified CSS class.
   * @param locator - The Playwright locator to check.
   * @param notExpectedClass - The CSS class that should NOT be present.
   * @param description - A description of the element for error messages.
   */
  static async expectNotHasClass(
    locator: Locator,
    notExpectedClass: string,
    description = 'Should NOT have class:',
  ) {
    await expect(locator, `[${description}] "${notExpectedClass}"`).not.toHaveClass(
      new RegExp(`\\b${notExpectedClass}\\b`),
    );
  }

  /**
   * Checks if the given locator contains the expected CSS class.
   * @param locator - The Playwright locator to check.
   * @param expectedClass - The CSS class that should be present.
   * @param description - A description of the element for error messages.
   */
  static async expectContainClass(
    locator: Locator,
    expectedClass: string,
    description = 'Should contain class:',
  ) {
    await expect(locator, `[${description}] "${expectedClass}"`).toContainClass(expectedClass);
  }

  /**
   * Checks if the given locator does NOT contain the specified CSS class.
   * @param locator - The Playwright locator to check.
   * @param forbiddenClass - The CSS class that should NOT be present.
   * @param description - A description of the element for error messages.
   */
  static async expectNotContainClass(
    locator: Locator,
    forbiddenClass: string,
    description = 'Should NOT contain class:',
  ) {
    await expect(locator, `[${description}] "${forbiddenClass}"`).not.toContainClass(
      forbiddenClass,
    );
  }

  /**
   * Checks if the current page has the expected title.
   * @param page - The Playwright Page object.
   * @param expectedTitle - The expected title (string or RegExp).
   * @param description - A description for error messages.
   */
  static async expectTitle(
    page: Page,
    expectedTitle: string | RegExp,
    description = 'Page should have title:',
  ) {
    await expect(page, `[${description}] "${expectedTitle}"`).toHaveTitle(expectedTitle);
  }

  /**
   * Checks if the given locator is enabled.
   * @param locator - The Playwright locator to check.
   * @param description - A description of the element for error messages.
   */
  static async expectIsEnabled(locator: Locator, description = 'Should be enabled.') {
    await expect(locator, description).toBeEnabled();
  }

  /**
   * Checks if the given locator is disabled.
   * @param locator - The Playwright locator to check.
   * @param description - A description of the element for error messages.
   */
  static async expectIsDisabled(locator: Locator, description = 'Should be disabled.') {
    await expect(locator, description).toBeDisabled();
  }

  /**
   * Checks if the given locator has a specific attribute with a specific value.
   * @param locator - The Playwright locator to check.
   * @param attribute - The name of the attribute.
   * @param value - The expected value of the attribute.
   * @param description - A description of the element for error messages.
   */
  static async expectToHaveAttribute(
    locator: Locator,
    attribute: string,
    value: string | RegExp,
    description = 'Should have attribute:',
  ) {
    await expect(locator, `[${description}] ${attribute}="${value}"`).toHaveAttribute(
      attribute,
      value,
    );
  }

  /**
   * Checks if the locator resolves to the expected number of elements.
   * @param locator - The Playwright locator to check.
   * @param count - The expected number of elements.
   * @param description - A description of the element for error messages.
   */
  static async expectToHaveCount(
    locator: Locator,
    count: number,
    description = 'Should have a count of:',
  ) {
    await expect(locator, `[${description}] ${count}`).toHaveCount(count);
  }

  /**
   * Checks if a locator's value matches the given string or regex.
   * @param locator The locator to check.
   * @param value The expected value.
   * @param description A description for the assertion.
   */
  static async expectToHaveValue(
    locator: Locator,
    value: string | RegExp,
    description = 'Should have value:',
  ) {
    await expect(locator, `[${description}] "${value}"`).toHaveValue(value);
  }

  /**
   * Checks if the given locator is attached to the DOM.
   * @param locator - The Playwright locator to check.
   * @param description - A description of the element for error messages.
   */
  static async expectIsAttached(locator: Locator, description = 'Element should be attached:') {
    await expect(locator, `[${description}]`).toBeAttached();
  }

  /**
   * Checks if the given condition is true.
   * @param condition - The boolean expression to check.
   * @param description - A description for error messages.
   */
  static expectTrue(condition: boolean, description = 'Expected value to be true') {
    expect(condition, description).toBeTruthy();
  }

  /**
   * Checks if the given condition is false.
   * @param condition - The boolean expression to check.
   * @param description - A description for error messages.
   */
  static expectFalse(condition: boolean, description = 'Expected value to be false') {
    expect(condition, description).toBeFalsy();
  }
}
