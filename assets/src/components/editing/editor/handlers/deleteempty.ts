import { KeyboardEvent } from 'react';
import { Editor, Element } from 'slate';
import { SlateEditor } from 'data/content/model/slate';
import { isEmptyContent } from 'data/content/utils';

// Which elements do we want to remove if they're empty?
export const emptyElementsToDelete = ['a', 'callout', 'callout_inline', 'foreign'];

const navKeys = [
  'ArrowLeft',
  'ArrowRight',
  'ArrowUp',
  'ArrowDown',
  'Home',
  'End',
  'PageUp',
  'PageDown',
];

let lastNormalize = -1;

/**
 * Normally, we normalize away empty links | callouts | foreign.
 *
 * However, if the cursor is inside the element, we do not immiediately delete it, because that would break a workflow where a user
 * clicks the toolbar button, and then starts typing the text for the element.
 *
 * This exposes us to the following case:
 *   - User clicks element button
 *   - Normalizer runs, sees the cursor inside an empty element, and leaves it alone.
 *   - User presses up arrow key
 *   - Normalizer does not run on navigation
 *   - User makes a change, such as typing a character
 *   - Normalizer runs, but only on the section of the document that changed, and does not remnove the empty element
 *
 * This key-down handler will detect when we press a navigation key, and if we're inside an empty element, it will force a
 * full document normalization.
 *
 *
 */
export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (navKeys.includes(e.key)) {
    const selectedNode = editor.selection && Editor.node(editor, editor.selection.focus);
    if (!selectedNode) return;
    const [_node, path] = selectedNode;

    const elements = Editor.above(editor, {
      match: (n) => Element.isElement(n) && emptyElementsToDelete.includes(n.type),
      at: path,
    });

    if (!elements) return;

    // Only need to normalize if our element is empty
    const anyEmpty = elements.some((element) => {
      return Element.isElement(element) && isEmptyContent(element.children);
    });

    if (anyEmpty) {
      console.info('Normalizing All Content: Possible empty element.');

      clearTimeout(lastNormalize); // I supposed someone could rapidly press navigation keys, so only do this once.

      lastNormalize = window.setTimeout(() => {
        Editor.normalize(editor, { force: true });
      }, 100);
    }
  }
};
