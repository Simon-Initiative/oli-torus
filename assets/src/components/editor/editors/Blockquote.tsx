import { KeyboardEvent } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Range, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';


const command: Command = {
  execute: (editor: ReactEditor) => {
    const quote = ContentModel.create<ContentModel.Blockquote>(
      { type: 'blockquote', children: [{ text: '' }], id: guid() });
    Transforms.insertNodes(editor, quote);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-quote-right',
  description: 'Quote',
  command,
};

export interface BlockQuoteProps extends EditorProps<ContentModel.Blockquote> {
}

export const BlockQuoteEditor = (props: BlockQuoteProps) => {

  const { attributes, children } = props;
  const style = {
    margin: '30px',
    backgroundColor: '#EEEEEE',
    borderLeft: 'solid 1px blue',
    padding: '5px',
  };

  return (
    <blockquote style={style} className="blockquote" {...attributes}>
      {children}
    </blockquote>
  );
};


// Handles exiting a blockquote on enter
function handleTermination(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection !== null && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'blockquote',
    });

    if (match) {
      const [, path] = match;

      const p = ContentModel.create<ContentModel.Paragraph>(
        { type: 'p', children: [{ text: '' }], id: guid() });

      // Insert it ahead of the next node
      const nextMatch = SlateEditor.next(editor, { at: path });
      if (nextMatch) {
        const [, nextPath] = nextMatch;
        Transforms.insertNodes(editor, p, { at: nextPath });

        const newNext = SlateEditor.next(editor, { at: path });
        if (newNext) {
          const [, newPath] = newNext;
          Transforms.select(editor, newPath);
        }


      // But if there is no next node, insert it at end
      } else {
        Transforms.insertNodes(editor, p, { mode: 'highest', at: SlateEditor.end(editor, []) });

        const newNext = SlateEditor.next(editor, { at: path });
        if (newNext) {
          const [, newPath] = newNext;
          Transforms.select(editor, newPath);
        }
      }

      e.preventDefault();

    }
  }
}

// The key down handler required to allow special list processing.
export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Enter') {
    handleTermination(editor, e);
  }
};
