import { expect, type Locator } from '@playwright/test';

/**
 * Student delivery helpers for vlab activities.
 *
 * These helpers simulate the postMessage-driven iframe integration so specs
 * can validate vlabvalue behavior deterministically.
 */

export async function sendVlabSelection(activity: Locator, flaskXml: string) {
  const iframe = activity.locator('iframe.vlab-holder').first();

  await expect(iframe).toBeVisible();

  await iframe.evaluate((node, xml) => {
    const frame = node as HTMLIFrameElement;

    if (!frame.contentWindow) {
      throw new Error('Vlab iframe contentWindow was not available');
    }

    (frame.contentWindow as Window & { getSelectedItem?: () => string }).getSelectedItem = () =>
      xml;

    window.dispatchEvent(new MessageEvent('message', { data: { source: 'playwright-vlab' } }));
  }, flaskXml);
}

export async function getVlabHiddenValue(activity: Locator) {
  const hiddenInput = activity.locator('input[type="hidden"]').first();

  await expect(hiddenInput).toBeAttached();

  return hiddenInput.inputValue();
}
