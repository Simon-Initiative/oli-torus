import { schema } from 'data/content/model';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';

export const withInlines = (editor: Editor & ReactEditor) => {
  editor.isInline = (element) => {
    try {
      const result = (schema as any)[element.type as string].isBlock;
      return !result;
    } catch (e) {
      return false;
    }
  };
  return editor;
};
