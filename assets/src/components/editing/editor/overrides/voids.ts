import { Editor } from 'slate';
import { schema } from 'data/content/model';

// Override isVoid to incorporate our schema's opinion on which
export const withVoids = (editor: Editor) => {
  editor.isVoid = (element) => {
    try {
      const result = (schema as any)[element.type as any].isVoid;
      return result;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
