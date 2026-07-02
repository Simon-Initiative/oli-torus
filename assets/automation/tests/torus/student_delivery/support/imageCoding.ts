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
