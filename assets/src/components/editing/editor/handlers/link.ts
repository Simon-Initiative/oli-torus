import { Editor, Element } from 'slate';
import { SlateEditor } from 'data/content/model/slate';
import { isEmptyContent } from 'data/content/utils';

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
 * Normally, we normalize away empty links.
 *
 * However, if the cursor is inside the link, we do not immiediately delete it, because that would break a workflow where a user
 * clicks the link button, and then starts typing the text for the link.
 *
 * This exposes us to the following case:
 *   - User clicks link button
 *   - Normalizer runs, sees the cursor inside an empty link, and leaves it alone.
 *   - User presses up arrow key
 *   - Normalizer does not run on navigation
 *   - User makes a change, such as typing a character
 *   - Normalizer runs, but only on the section of the document that changed, and does not remnove the empty link
 *
 * This key-down handler will detect when we press a navigation key, and if we're inside an empty link, it will force a
 * full document normalization.
 *
 *
 */
export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (navKeys.includes(e.key)) {
    const selectedNode = editor.selection && Editor.node(editor, editor.selection.focus);
    if (!selectedNode) return;
    const [_node, path] = selectedNode;

    const linkElements = Editor.above(editor, {
      match: (n) => Element.isElement(n) && n.type === 'a',
      at: path,
    });

    if (!linkElements) return;

    // Only need to normalize if our link element is empty
    const anyEmpty = linkElements.some((linkElement) => {
      return Element.isElement(linkElement) && isEmptyContent(linkElement.children);
    });

    if (anyEmpty) {
      console.info('Normalizing All Content: Possible empty link.');

      clearTimeout(lastNormalize); // I supposed someone could rapidly press navigation keys, so only do this once.

      lastNormalize = window.setTimeout(() => {
        Editor.normalize(editor, { force: true });
      }, 100);

    }
  }
};
