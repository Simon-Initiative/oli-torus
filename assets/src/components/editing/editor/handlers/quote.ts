import { Transforms, Range, Path, Editor as SlateEditor, Element, Text } from 'slate';
import { KeyboardEvent } from 'react';
import { Model } from 'data/content/model/elements/factories';

export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleTermination(editor, e);
  }
};

function handleTermination(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    const [quoteMatch] = SlateEditor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === 'blockquote',
    });

    if (quoteMatch) {
      const [, path] = quoteMatch;
      const pMatch = SlateEditor.above(editor);

      if (!pMatch) {
        return;
      }
      const [p] = pMatch;

      if (
        Element.isElement(p) &&
        p.type === 'p' &&
        Text.isText(p.children[0]) &&
        p.children[0].text === ''
      ) {
        // remove the blockquote item and add a paragraph
        // outside of the parent blockquote
        Transforms.removeNodes(editor);

        // Insert it ahead of the next node
        Transforms.insertNodes(editor, Model.p(), {
          at: Path.next(path),
        });
        Transforms.select(editor, Path.next(path));

        e.preventDefault();
      }
    }
  }
}
