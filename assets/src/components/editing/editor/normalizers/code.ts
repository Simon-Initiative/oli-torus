import { ModelElement } from 'data/content/model/elements/types';
import { schema } from 'data/content/model/schema';
import { FormattedText } from 'data/content/model/text';
import { Editor, Element, Path, Text, Transforms } from 'slate';
import guid from 'utils/guid';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {
  const [parent] = Editor.parent(editor, path);

  if (Element.isElement(parent)) {
    const config = schema[parent.type];
    // code
    if (parent.type === 'code') {
      if (Text.isText(node)) {
        Transforms.wrapNodes(editor, { type: 'code_line', id: guid(), children: [] }, { at: path });
        console.warn('Normalizing content: wrapping code_line in code block');
        return true;
      }
      if (Element.isElement(node) && !config.validChildren[node.type]) {
        Transforms.setNodes(editor, { type: 'code_line' }, { at: path });
        console.warn('Normalizing content: setting code_line type inside code block');
        return true;
      }
    }
  }
  return false;
};
