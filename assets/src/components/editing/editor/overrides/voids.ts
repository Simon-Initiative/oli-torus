import { schema } from 'data/content/model';
import { Editor, Element } from 'slate';

// Override isVoid to incorporate our schema's opinion on which
export const withVoids = (editor: Editor) => {
  editor.isVoid = (element) => {
    try {
      if (Element.isElement(element)) {
        return schema[element.type as string].isVoid;
      }
      return false;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
