import { Transforms, Path, Editor, Element, Text } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { ModelElement } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import { schema } from 'data/content/model/schema';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {
  const [parent] = Editor.parent(editor, path);
  if (Element.isElement(parent)) {
    const config = schema[parent.type];
    if (['ol', 'ul'].includes(parent.type)) {
      if (Text.isText(node)) {
        Transforms.wrapNodes(editor, Model.li(), { at: path });
        console.warn('Normalizing content: Wrapping text in list with list item');
        return true;
      }
      if (Element.isElement(node) && !config.validChildren[node.type]) {
        Transforms.setNodes(editor, { type: 'li' }, { at: path });
        console.warn('Normalizing content: Changing node in list to list item type');
        return true;
      }
    }
  }
  return false;
};
