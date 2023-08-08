import { Editor, Element, Path, Text, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { ListItem, ModelElement } from 'data/content/model/elements/types';
import { schema } from 'data/content/model/schema';
import { FormattedText } from 'data/content/model/text';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {
  if (Element.isElement(node) && node.type === 'li') {
    const allInlineChildren = node.children.every(
      (child) => Editor.isInline(editor, child) || Text.isText(child),
    );
    if (node.children.length > 0 && allInlineChildren) {
      console.warn(
        'Normalizing content: Had an LI with all inline elements. Wrapping children in paragraph',
      );

      Transforms.removeNodes(editor, { at: path });

      const newLI = {
        ...node,
        children: [{ ...Model.p(), children: node.children }],
      } as ListItem;

      Transforms.insertNodes(editor, newLI, { at: path });
      return true;
    }
  }

  const [parent] = Editor.parent(editor, path);
  if (Element.isElement(parent)) {
    const parentConfig = schema[parent.type];
    if (['ol', 'ul'].includes(parent.type)) {
      if (Text.isText(node)) {
        Transforms.wrapNodes(editor, Model.li(), { at: path });
        console.warn('Normalizing content: Wrapping text in list with list item');
        return true;
      }
      if (Element.isElement(node) && !parentConfig.validChildren[node.type]) {
        Transforms.wrapNodes(editor, Model.li(), { at: path });
        console.warn('Normalizing content: Wrapping node in list to list item type');
        return true;
      }
    }
  }
  return false;
};
