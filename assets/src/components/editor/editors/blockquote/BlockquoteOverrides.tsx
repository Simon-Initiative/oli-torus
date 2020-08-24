import { Transforms, Range, Path, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { KeyboardEvent } from 'react';
import { isActiveList } from 'components/editor/utils';

export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleTermination(editor, e);
  }
};

function handleTermination(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {

    const [quoteMatch] = SlateEditor.nodes(editor, {
      match: n => n.type === 'blockquote',
    });

    if (quoteMatch) {
      const [node, path] = quoteMatch;
      const pMatch = SlateEditor.above(editor);

      if (!pMatch) {
        return;
      }
      const [p, pPath] = pMatch;

      if (p.type === 'p' && p.children[0].text === '') {
        console.log('here')
        // remove the blockquote item and add a paragraph
        // outside of the parent blockquote
        Transforms.removeNodes(editor);

        // Insert it ahead of the next node
        Transforms.insertNodes(editor, ContentModel.p(), { at: Path.next(path) });
        Transforms.select(editor, Path.next(path));

        e.preventDefault();
      }
    }
  }
}
