import { ReactEditor } from 'slate-react';
import { Transforms, Range, Node, Point, Path, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc, CommandContext } from '../interfaces';
import guid from 'utils/guid';
import { KeyboardEvent } from 'react';

const li = () => ContentModel.create<ContentModel.ListItem>(
  { type: 'li', children: [{ text: '' }], id: guid() });

const ol = () => ContentModel.create<ContentModel.OrderedList>(
  { type: 'ol', children: [li()], id: guid() });

const ul = () => ContentModel.create<ContentModel.UnorderedList>(
  { type: 'ul', children: [li()], id: guid() });


const toggleList = (editor: ReactEditor, listType: string) => {

  try {

    // The edits here result in intermediate states that normalization
    // would seek to correct.  So to allow this operation to succeed,
    // we instruct our editor instance to suspend normalization.
    (editor as any).suspendNormalization = true;

    const isActive = isActiveList(editor);

    Transforms.unwrapNodes(editor, {
      match: n => n.type === 'ul' || n.type === 'ol',
      split: true,
    });

    Transforms.setNodes(editor, {
      type: isActive ? 'p' : 'li',
    });

    if (!isActive) {
      const block = { type: listType, children: [] };
      Transforms.wrapNodes(editor, block);
    }
  } catch (error) {
    // tslint:disable-next-line
    console.error(error);

  } finally {
    // Whether the operation succeeded or failed, we restore
    // normalization
    (editor as any).suspendNormalization = false;
  }

};

const isActiveList = (editor: ReactEditor) => {
  const [match] = SlateEditor.nodes(editor, {
    match: n => n.type === 'ul' || n.type === 'ol',
  });

  return !!match;
};

const listCommandMaker = (listType: string) => {
  return {
    execute: (context: CommandContext, editor: ReactEditor) => {
      toggleList(editor, listType);
    },
    precondition: (editor: ReactEditor) => {
      return true;
    },
  };
};

const ulCommand: Command = listCommandMaker('ul');
const olCommand: Command = listCommandMaker('ol');

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

// Handles a 'tab' key down event that may indent a list item.
function handleIndent(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection !== null && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'li',
    });

    if (match) {
      const [current, path] = match;
      const start = SlateEditor.start(editor, path);

      // If the cursor is at the beginning of a list item
      if (Point.equals(editor.selection.anchor, start)) {

        const parentMatch = SlateEditor.parent(editor, path);
        const [parent, parentPath] = parentMatch;

        if (isList(parent)) {

          // Make sure the user is not on the first item
          if (parent.children.length > 0 && parent.children[0] !== current) {

            // Now find a sublist, if any
            for (let i = 0; i < parent.children.length; i += 1) {
              const item = parent.children[i];
              if (isList(item)) {

                const newList = item.type === 'ul' ? ul() : ol();
                newList.children.pop();

                Transforms.wrapNodes(editor, newList, { at: editor.selection });
                e.preventDefault();
                return;
              }
            }
          }

          // Allow indent with the same list type as current parent
          const newList = parent.type === 'ul' ? ul() : ol();
          newList.children.pop();

          Transforms.wrapNodes(editor, newList, { at: editor.selection });
          e.preventDefault();

        }

      }
    }
  }
}

// Handles a shift+tab press to possibly outdent a list item
function handleOutdent(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection !== null && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'li',
    });

    if (match) {
      const [, path] = match;
      const start = SlateEditor.start(editor, path);

      // If the cursor is at the beginning of a list item
      if (Point.equals(editor.selection.anchor, start)) {

        // Check to see if the list item is in a nested list
        const parentMatch = SlateEditor.parent(editor, path);
        const [parent, parentPath] = parentMatch;
        const grandParentMatch = SlateEditor.parent(editor, parentPath);
        const [grandParent] = grandParentMatch;

        if (isList(grandParent) && isList(parent)) {

          // Lift the current node up one level, effectively promoting
          // it up as a list item into the parent list
          Transforms.liftNodes(editor, { at: editor.selection });
          e.preventDefault();
        }
      }
    }
  }
}

// Handles pressing enter on an empty list item to turn it
// This handler should fail fast - given that every enter press
// in the editor passes through it
function handleTermination(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection !== null && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'li',
    });

    if (match) {
      const [node, path] = match;

      if ((node.children as any).length === 1 && (node.children as any)[0].text === '') {

        const parentMatch = SlateEditor.parent(editor, path);
        const [parent, parentPath] = parentMatch;
        const grandParentMatch = SlateEditor.parent(editor, parentPath);
        const [grandParent, grandParentPath] = grandParentMatch;

        // If we are in a nested list we want to simply outdent
        if (isList(grandParent) && isList(parent)) {
          handleOutdent(editor, e);
        } else {
          // otherwise, remove the list item and add a paragraph
          // outside of the parent list
          Transforms.removeNodes(editor, { at: path });

          const p = ContentModel.create<ContentModel.Paragraph>(
            { type: 'p', children: [{ text: '' }], id: guid() + ''  });

          // Insert it ahead of the next node
          Transforms.insertNodes(editor, p, { at: Path.next(parentPath) });
          Transforms.select(editor, Path.next(parentPath));

          e.preventDefault();
        }
      }
    }
  }
}

// The key down handler required to allow special list processing.
export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  if (e.key === 'Tab' && e.shiftKey) {
    handleOutdent(editor, e);
  } else if (e.key === 'Tab' && !e.shiftKey) {
    handleIndent(editor, e);
  } else if (e.key === 'Enter') {
    handleTermination(editor, e);
  }
};

