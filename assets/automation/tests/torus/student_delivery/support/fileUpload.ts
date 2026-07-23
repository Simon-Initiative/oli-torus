import { type Locator, type Page } from '@playwright/test';

/**
 * Student delivery helpers for File Upload activities.
 *
 * The delivery element tag is stable; the inner root class is a copy-paste artifact
 * (`cata-activity`) and is intentionally not relied upon. The file input is hidden
 * (`display:none`) and triggered via a visible "Upload" button, so specs drive it with
 * `setInputFiles` directly on the input rather than clicking the button.
 */

export function fileUploadActivity(page: Page): Locator {
  return page.locator('oli-file-upload-delivery').first();
}

export function fileUploadInput(activity: Locator): Locator {
  return activity.locator('input[type="file"]');
}

export function fileUploadSubmit(activity: Locator): Locator {
  return activity.getByRole('button', { name: 'submit', exact: true });
}

export function fileUploadListItems(activity: Locator): Locator {
  return activity.locator('.list-group-item');
}

export function fileUploadError(activity: Locator): Locator {
  return activity.locator('.alert.alert-danger');
}
