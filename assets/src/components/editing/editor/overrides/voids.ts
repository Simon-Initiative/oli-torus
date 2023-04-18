import { Editor } from 'slate';
import { schema } from 'data/content/model/schema';

// Override isVoid to incorporate our schema's opinion on which
export const withVoids = (editor: Editor) => {
  editor.isVoid = (element) => {
    try {
      return schema[element.type].isVoid;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
