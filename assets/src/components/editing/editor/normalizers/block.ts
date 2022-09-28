import { ModelElement } from 'data/content/model/elements/types';
import { schema } from 'data/content/model/schema';
import { FormattedText } from 'data/content/model/text';
import { Editor, Element, Path, Transforms } from 'slate';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {
  const [parent, parentPath] = Editor.parent(editor, path);
  if (Element.isElement(parent)) {
    const config = schema[parent.type];

    // As a fallback, if we can't reconcile the content, just delete it.
    if (Editor.isBlock(editor, node)) {
      if (Element.isElement(node) && !config.validChildren[node.type]) {
        // Special case for code blocks -- they have two wrappers (code, code_line),
        // so deletion removes the inner block and causes validation errors
        if (node.type === 'p' && parent.type === 'code') {
          Transforms.removeNodes(editor, { at: parentPath });
          console.warn('Normalizing content: Special case code, removing node', node.type);
          return true;
        }

        Transforms.unwrapNodes(editor, { at: path });
        console.warn('Normalizing content: Invalid child type for parent', node.type, parent.type);
        return true;
      }
    }

    // Check the top-level constraints
    if (Editor.isBlock(editor, node) && !schema[node.type].isTopLevel) {
      if (Editor.isEditor(parent)) {
        Transforms.unwrapNodes(editor, { at: path });
        console.warn('Normalizing content: Unwrapping top level block node', node.type);
        return true;
      }
    }
  }
  return false;
};
