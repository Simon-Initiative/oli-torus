import { Editor } from 'slate';
import { schema } from 'data/content/model/schema';

export const withInlines = (editor: Editor) => {
  editor.isInline = (element) => {
    try {
      return !schema[element.type].isBlock;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
