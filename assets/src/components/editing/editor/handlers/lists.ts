import { KeyboardEvent } from 'react';
import {
  Editor,
  Element,
  Node,
  Path,
  Point,
  Range,
  Editor as SlateEditor,
  Text,
  Transforms,
} from 'slate';
import { Location } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { OrderedList, UnorderedList } from 'data/content/model/elements/types';
import { ListItem } from '../../../../data/content/model/elements/types';
import { findNearestBlock } from '../../slateUtils';

// The key down handler required to allow special list processing.
export const onKeyDown = (editor: SlateEditor, e: KeyboardEvent) => {
  try {
    if (e.key === 'Tab' && e.shiftKey && isInsideList(editor)) {
      handleOutdent(editor, e);
    } else if (e.key === 'Tab' && !e.shiftKey && isInsideList(editor)) {
      handleIndent(editor, e);
    } else if (e.key === 'Enter' && isInsideList(editor)) {
      if (e.shiftKey) {
        // Inside a list, shift+enter should behave as a default enter press.
        e.shiftKey = false;
        return;
      }
      handleEnter(editor, e);
    }
  } catch (e) {
    console.error('editor.handlers.lists::onKeyDown failed with:', e);
  }
};

// Returns true if any parent is a list.
const isInsideList = (editor: SlateEditor) => {
  const [match] = SlateEditor.nodes(editor, {
    match: (n) => Element.isElement(n) && (n.type === 'ul' || n.type === 'ol'),
  });

  return !!match;
};

const isList = (n: Node): n is UnorderedList | OrderedList =>
  Element.isElement(n) && (n.type === 'ul' || n.type === 'ol');

// Handles a 'tab' key down event that may indent a list item.
export function handleIndent(editor: SlateEditor, e?: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    const [match] = SlateEditor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === 'li',
    });

    if (match) {
      const [current, path] = match;
      const start = SlateEditor.start(editor, path);

      // If the cursor is at the beginning of a list item
      if (Point.equals(editor.selection.anchor, start)) {
        const parentMatch = SlateEditor.parent(editor, path);
        const [parent] = parentMatch;

        if (isList(parent)) {
          // Make sure the user is not on the first item
          if (parent.children.length > 0 && parent.children[0] !== current) {
            // Now find a sublist, if any
            for (let i = 0; i < parent.children.length; i += 1) {
              const item = parent.children[i];
              if (isList(item)) {
                const newList = item.type === 'ul' ? Model.ul() : Model.ol();
                newList.children.pop();

                Transforms.wrapNodes(editor, newList, { at: editor.selection });
                e?.preventDefault();
                return;
              }
            }
          }

          // Allow indent with the same list type as current parent
          const newList = parent.type === 'ul' ? Model.ul() : Model.ol();
          newList.children.pop();

          Transforms.wrapNodes(editor, newList, { at: editor.selection });
          e?.preventDefault();
        }
      }
    }
  }
}

// Handles a shift+tab press to possibly outdent a list item
export function handleOutdent(editor: SlateEditor, e?: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    const [match] = SlateEditor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === 'li',
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
          e?.preventDefault();
        }
      }
    }
  }
}

const isLastListItem = (editor: SlateEditor, listItemPath: Path) => {
  const [listItem] = SlateEditor.node(editor, listItemPath);
  const [list] = SlateEditor.parent(editor, listItemPath);
  return list.children[list.children.length - 1] === listItem;
};

// Empty = A node with a single paragraph child that contains no text.
const isEmpty = (node: any) =>
  node.children?.length === 1 &&
  node.children[0].type === 'p' &&
  node.children[0].children?.length === 1 &&
  Text.isText(node.children[0].children[0]) &&
  ((node.children[0].children[0].text || '') as string).trim() === '';

// Handles pressing enter on an list item.
//   - On empty - terminate the list
//   - On Content - create a new list item
function handleEnter(editor: SlateEditor, e: KeyboardEvent) {
  if (editor.selection && Range.isCollapsed(editor.selection)) {
    const [listItemMatch] = SlateEditor.nodes<ListItem>(editor, {
      match: (n) => Element.isElement(n) && n.type === 'li',
    });

    if (listItemMatch) {
      const [listItemNode, listItemPath] = listItemMatch;
      if (isEmpty(listItemNode) && isLastListItem(editor, listItemPath)) {
        // TODO: We should only terminate if it's the last list item, right now, this does weird things when hitting enter on an empty LI in the middle of the list.
        console.info('Terminate list');
        terminateList(editor, listItemPath, e);
      } else {
        console.info('append list item');
        createListItem(editor, listItemPath, e);
      }
    }
  }
}

const isAtStartOfListItem = (editor: SlateEditor, listItemPath: Path) => {
  if (!editor.selection) return false;
  try {
    const end = SlateEditor.start(editor, listItemPath);
    return Point.equals(editor.selection.anchor, end);
  } catch (e) {
    return false;
  }
};

const isAtEndOfListItem = (editor: SlateEditor, listItemPath: Path) => {
  if (!editor.selection) return false;
  try {
    const end = SlateEditor.end(editor, listItemPath);
    return Point.equals(editor.selection.anchor, end);
  } catch (e) {
    return false;
  }
};

const createListItem = (editor: SlateEditor, listItemPath: Path, e: KeyboardEvent) => {
  const [listItem] = SlateEditor.node(editor, listItemPath);

  // If we have a list item, split it into two list items
  if (listItem && editor.selection) {
    //const [current, path] = listItemPath;
    e.preventDefault();

    // If the cursor is at the beginning of a list item
    if (isAtStartOfListItem(editor, listItemPath)) {
      console.info('Inserting LI before current LI', listItemPath);
      Transforms.insertNodes(editor, Model.li(), { at: listItemPath });
    } else if (isAtEndOfListItem(editor, listItemPath)) {
      console.info('Inserting LI after current LI', listItemPath);
      Editor.withoutNormalizing(editor, () => {
        const newListItemPath = Path.next(listItemPath);
        Transforms.insertNodes(editor, Model.li(), { at: newListItemPath, select: true });
      });
    } else {
      console.info('MID?');
      const nearestBlock = findNearestBlock(editor);
      if (!nearestBlock) return;
      console.info({ nearestBlock });
      Editor.withoutNormalizing(editor, () => {
        const [, /*bottomElement*/ bottomElementPath] = nearestBlock;
        const newListItemPath = Path.next(listItemPath);
        console.info('Children start', editor.children[1]);

        // Split the current block into two blocks, the second one gets moved into the new LI below.
        Transforms.splitNodes(editor);
        console.info('Children after split', editor.children[1]);

        // A new list item that we'll move content into.
        Transforms.insertNodes(editor, Model.li(), {
          at: newListItemPath,
        });
        console.info('Children after insert li', editor.children[1]);

        const newlySplitNodePath = Path.next(bottomElementPath);
        let count = 0;
        while (Node.has(editor, newlySplitNodePath)) {
          /* Need the while loop because there might be multiple block elements that need to be moved. Imaging a paragraph followed by an image, and
             the cursor is in the middle of the paragraph.

             Starts as:  <li><p>Some text</p><img /></li>
             Then we add an empty li: <li><p>Some text</p><img /></li><li></li>
             Then the p gets split: <li><p>Some</p><p>text</p><img /></li>
                 That new p is now at path newlySplitNodePath
             Then we move the second p into the new li: <li><p>Some</p></li><li><p>text</p><img /></li>
                 Now, the image is at newlySplitNodePath because the node before it was moved.
             Then we move the img into the new li: <li><p>Some</p></li><li><p>text</p><img /></li>
          */
          Transforms.moveNodes(editor, {
            at: newlySplitNodePath,
            to: [...newListItemPath, count++],
          });
          console.info('Children after move', editor.children[1]);
        }

        Transforms.removeNodes(editor, { at: [...newListItemPath, count] }); // Get rid of the empty paragraph, can't do this before moving in nodes or slate errors.
        Transforms.select(editor, {
          path: [...newListItemPath, 0, 0],
          offset: 0,
        }); // Put cursor in right spot
        console.info('Children after trim', editor.children[1]);
      });
    }
  }
};

const terminateList = (editor: SlateEditor, listItemPath: Location, e: KeyboardEvent) => {
  const parentMatch = SlateEditor.parent(editor, listItemPath);
  const [parent, parentPath] = parentMatch;
  const grandParentMatch = SlateEditor.parent(editor, parentPath);
  const [grandParent] = grandParentMatch;

  // If we are in a nested list we want to simply outdent
  if (isList(grandParent) && isList(parent)) {
    handleOutdent(editor, e);
  } else {
    // otherwise, remove the list item and add a paragraph
    // outside of the parent list
    Transforms.removeNodes(editor, { at: listItemPath });

    // Insert it ahead of the next node
    Transforms.insertNodes(editor, Model.p(), { at: Path.next(parentPath) });
    Transforms.select(editor, Path.next(parentPath));
    e.preventDefault();
  }
};
