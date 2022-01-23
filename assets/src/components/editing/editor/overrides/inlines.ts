import { schema } from 'data/content/model/schema';
import { Editor } from 'slate';

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
