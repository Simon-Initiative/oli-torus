import { expect, type Locator } from '@playwright/test';

/**
 * Student delivery helpers for image coding activities.
 *
 * These helpers hide the implementation details of interacting with the
 * embedded Ace editor so specs can focus on learner behavior.
 */

/**
 * Replaces the current source in the Ace editor with the provided code by
 * using the editor instance attached to the rendered `.ace_editor` element.
 */
export async function setImageCodingSource(activity: Locator, code: string) {
  const editor = activity.locator('.ace_editor').first();

  await expect(editor).toBeVisible();

  await editor.evaluate((node, value) => {
    const aceEditor = (
      node as HTMLDivElement & {
        env?: {
          editor?: {
            setValue: (code: string, cursorPos?: number) => void;
            clearSelection: () => void;
          };
        };
      }
    ).env?.editor;

    if (!aceEditor) {
      throw new Error('Ace editor instance was not available');
    }

    aceEditor.setValue(value, -1);
    aceEditor.clearSelection();
  }, code);
}

/**
 * Returns the current source from the rendered Ace editor instance.
 */
export async function getImageCodingSource(activity: Locator) {
  const editor = activity.locator('.ace_editor').first();

  await expect(editor).toBeVisible();

  return editor.evaluate((node) => {
    const aceEditor = (
      node as HTMLDivElement & {
        env?: {
          editor?: {
            getValue: () => string;
          };
        };
      }
    ).env?.editor;

    if (!aceEditor) {
      throw new Error('Ace editor instance was not available');
    }

    return aceEditor.getValue();
  });
}

/**
 * Waits until the Ace editor source matches the expected code. This is useful
 * after reloads, where the editor can become visible before Torus restores the
 * learner's saved draft into the activity state.
 */
export async function expectImageCodingSource(activity: Locator, expectedCode: string) {
  await expect
    .poll(async () => getImageCodingSource(activity), {
      timeout: 10000,
      intervals: [250, 500, 1000],
    })
    .toBe(expectedCode);
}

/**
 * Returns the rendered result canvas used by image-processing image coding
 * activities after a successful run.
 */
export function imageCodingResultCanvas(activity: Locator) {
  return activity.locator('div[style*="white-space: pre-wrap;"] canvas').first();
}

/**
 * Retries the Run action until image-processing output finishes rendering to a
 * non-empty canvas.
 */
export async function runImageCodingUntilCanvasReady(activity: Locator, resultCanvas: Locator) {
  const runButton = activity.getByRole('button', { name: 'Run', exact: true });

  // Image resources load asynchronously, so the first run can fail with the
  // activity's transient "wait a bit and retry" error even though the setup is correct.
  // A rendered result canvas is the reliable success signal for image-processing runs.
  await expect
    .poll(
      async () => {
        await runButton.click();
        return resultCanvas.evaluate((node) => (node as HTMLCanvasElement).width);
      },
      {
        timeout: 10000,
        intervals: [250, 500, 1000],
      },
    )
    .toBeGreaterThan(0);
}

/**
 * Retries the Run action until table-processing output renders the expected
 * text response.
 */
export async function runImageCodingUntilTextReady(
  activity: Locator,
  output: Locator,
  expectedText: string,
) {
  const runButton = activity.getByRole('button', { name: 'Run', exact: true });

  // Table-processing resources also load asynchronously, so the first run can
  // hit runtime errors before the CSV text is available to SimpleTable.
  await expect
    .poll(
      async () => {
        await runButton.click();
        return output.textContent();
      },
      {
        timeout: 10000,
        intervals: [250, 500, 1000],
      },
    )
    .toContain(expectedText);
}
