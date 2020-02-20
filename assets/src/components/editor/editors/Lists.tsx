import { ReactEditor } from 'slate-react';
import { Transforms, Range, Node, Point, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import guid from 'utils/guid';
import { KeyboardEvent } from 'react';

const li = () => ContentModel.create<ContentModel.ListItem>(
  { type: 'li', children: [{ text: '' }], id: guid() });

const ol = () => ContentModel.create<ContentModel.OrderedList>(
  { type: 'ol', children: [li()], id: guid() });

const ul = () => ContentModel.create<ContentModel.UnorderedList>(
  { type: 'ul', children: [li()], id: guid() });

const ulCommand: Command = {
  execute: (editor: ReactEditor) => {
    Transforms.insertNodes(editor, ul());
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

const olCommand: Command = {
  execute: (editor: ReactEditor) => {
    Transforms.insertNodes(editor, ol());
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

export const ulCommanDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-list-ul',
  description: 'Unordered List',
  command: ulCommand,
};

export const olCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-list-ol',
  description: 'Ordered List',
  command: olCommand,
};

const isList = (n: Node) => n.type === 'ul' || n.type === 'ol';

export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Tab') {
    if (editor.selection !== null && Range.isCollapsed(editor.selection)) {
      const [match] = SlateEditor.nodes(editor, {
        match: n => n.type === 'li',
      });

      if (match) {
        const [, path] = match;
        const start = SlateEditor.start(editor, path);

        // If the cursor is at the beginning of a list item
        if (Point.equals(editor.selection.anchor, start)) {

          if (e.shiftKey) {

            // Check to see if the list item is in a nested list
            const parentMatch = SlateEditor.parent(editor, path);
            const [parent, parentPath] = parentMatch;
            const grandParentMatch = SlateEditor.parent(editor, parentPath);
            const [grandParent,] = grandParentMatch;

            if (isList(grandParent) && isList(parent)) {

              // Lift the current node up one level, effectively promoting
              // it up as a list item into the parent list
              Transforms.liftNodes(editor, { at: editor.selection });
              e.preventDefault();
            }
          } else {


          }
        }
      }
    }
  }
}


export const withLists = (editor: ReactEditor) => {
  const { deleteBackward } = editor;

  editor.deleteBackward = (...args) => {
    const { selection } = editor;

    if (selection && Range.isCollapsed(selection)) {
      const [match] = SlateEditor.nodes(editor, {
        match: n => n.type === 'li',
      })

      if (match) {
        const [, path] = match;
        const start = SlateEditor.start(editor, path);

        if (Point.equals(selection.anchor, start)) {
          Transforms.setNodes(
            editor,
            { type: 'p' },
            { match: n => n.type === 'li' }
          );
          return;
        }
      }
    }

    deleteBackward(...args);
  }

  return editor;
}
