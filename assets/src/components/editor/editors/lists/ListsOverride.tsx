import { Transforms, Range, Node, Point, Path, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { KeyboardEvent } from 'react';

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

const isList = (n: Node) => n.type === 'ul' || n.type === 'ol';

// Handles a 'tab' key down event that may indent a list item.
function handleIndent(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {

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

                const newList = item.type === 'ul' ? ContentModel.ul() : ContentModel.ol();
                newList.children.pop();

                Transforms.wrapNodes(editor, newList, { at: editor.selection });
                e.preventDefault();
                return;
              }
            }
          }

          // Allow indent with the same list type as current parent
          const newList = parent.type === 'ul' ? ContentModel.ul() : ContentModel.ol();
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
  if (editor.selection && Range.isCollapsed(editor.selection)) {

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
  if (editor.selection && Range.isCollapsed(editor.selection)) {

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

          // Insert it ahead of the next node
          Transforms.insertNodes(editor, ContentModel.p(), { at: Path.next(parentPath) });
          Transforms.select(editor, Path.next(parentPath));

          e.preventDefault();
        }
      }
    }
  }
}
