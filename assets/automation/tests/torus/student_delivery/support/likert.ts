import { type Locator, type Page } from '@playwright/test';

/**
 * Student delivery helpers for Likert activities.
 *
 * Likert renders each scale as a table of radio inputs. These helpers centralize
 * the activity, radio, and submit locators so specs read as learner behavior.
 * The delivery element tag is stable; the inner root class is a copy-paste
 * artifact (`multiple-choice-activity`) and is intentionally not relied upon.
 */

export function likertActivity(page: Page): Locator {
  return page.locator('oli-likert-delivery').first();
}

export function likertRadios(activity: Locator): Locator {
  return activity.locator('input.oli-radio');
}

export function likertSubmit(activity: Locator): Locator {
  return activity.getByRole('button', { name: 'submit', exact: true });
}
