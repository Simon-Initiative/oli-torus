import { type Locator, type Page } from '@playwright/test';

/**
 * Student delivery helpers for Directed Discussion activities.
 *
 * Directed discussion has no submit/evaluate step; the learner types in the top-level
 * "Create your new post..." textarea and clicks "Post". The post round-trips through the
 * discussion REST API and is merged into the local thread, so the poster sees their own
 * post without a Phoenix channel. The delivery element tag is stable; the inner root class
 * is a copy-paste artifact (`mc-activity`) and is intentionally not relied upon.
 */

export function directedDiscussionActivity(page: Page): Locator {
  return page.locator('oli-directed-discussion-delivery').first();
}

export function newPostTextarea(activity: Locator): Locator {
  return activity.getByPlaceholder('Create your new post...');
}

export function postButton(activity: Locator): Locator {
  return activity.getByRole('button', { name: 'Post', exact: true });
}
