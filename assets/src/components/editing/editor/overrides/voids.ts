import { Editor, Node } from 'slate';
import { schema } from 'data/content/model';
import { ReactEditor } from 'slate-react';

// Override isVoid to incorporate our schema's opinion on which
export const withVoids = (editor: Editor & ReactEditor) => {
  const { insertData } = editor;

  console.log('with voids');

  // editor.insertData = (data) => {
  //   const fragment = data.getData('application/x-slate-fragment');
  //   console.log('fragment', fragment);

  //   if (fragment) {
  //     const decoded = decodeURIComponent(window.atob(fragment));
  //     const parsed = JSON.parse(decoded) as Node[];
  //     console.log('parsed', parsed);
  //     editor.insertFragment(parsed);
  //     return editor;
  //   }

  //   insertData(data);
  // };

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
