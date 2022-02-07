import { Transforms, Path, Editor, Element, Text } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import { schema } from 'data/content/model/schema';
import guid from 'utils/guid';

export const normalize = (editor: Editor, node: ModelElement | FormattedText, path: Path) => {
  const [parent] = Editor.parent(editor, path);

  if (Element.isElement(parent)) {
    const config = schema[parent.type];
    // code
    if (parent.type === 'code') {
      if (Text.isText(node)) {
        Transforms.wrapNodes(editor, { type: 'code_line', id: guid(), children: [] }, { at: path });
        return;
      }
      if (Element.isElement(node) && !config.validChildren[node.type]) {
        Transforms.setNodes(editor, { type: 'code_line' }, { at: path });
        return;
      }
    }
  }
};
