import { schema } from 'data/content/model/schema';
import { Editor, Element } from 'slate';

export const withInlines = (editor: Editor) => {
  editor.isInline = (element) => {
    try {
      if (Element.isElement(element)) {
        return !schema[element.type as string].isBlock;
      }
      return false;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
