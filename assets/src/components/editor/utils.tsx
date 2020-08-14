import { Node, Editor, Text } from 'slate';
import { ReactEditor } from 'slate-react';
import { Marks, schema, Mark } from 'data/content/model';
import { Maybe } from 'tsmonad';

// Returns true if a text node contains at least one mark
export function hasMark(textNode: Text): boolean {
  return Object.keys(textNode).some(k => k in Marks);
}

// Returns all the Text nodes in the current selection
export function textNodesInSelection(editor: ReactEditor) {
  const selection = editor.selection;
  if (!selection) {
    return [];
  }

  return Node.fragment(editor, selection)
    .map(node => Array.from(Node.descendants(node))
      .reduce((acc: Text[], [node]) => {
        return Text.isText(node) ? acc.concat(node) : acc;
      }, []))
    .reduce((acc, curr) => acc.concat(curr), []);
}

// Returns a Mark[] that apply to the entire current selection
export function marksInEntireSelection(editor: ReactEditor) {
  const marks: any = {};
  const textNodes = textNodesInSelection(editor);
  textNodes.forEach((text) => {
    Object.keys(text)
      .filter(k => k in Marks)
      .forEach(mark => marks[mark] ? marks[mark] += 1 : marks[mark] = 1);
  });
  return Object.entries(marks)
    .filter(([, v]) => v === textNodes.length)
    .map(([k]) => k);
}

// Returns a Mark[] of all marks that exist in any part of the current selection
export function marksInPartOfSelection(editor: ReactEditor) {
  const marks: any = {};
  textNodesInSelection(editor)
    .forEach((text) => {
      Object.keys(text)
        .filter(k => k in Marks)
        .forEach(mark => marks[mark] = true);
    });
  return Object.keys(marks);
}

// Extracts the text from a hierarchy of nodes
export function toSimpleText(node: Node): string {
  return toSimpleTextHelper(node, '');
}

function toSimpleTextHelper(node: Node, text: string): string {

  return (node.children as any).reduce((p: string, c: any) => {
    let updatedText = p;
    if (c.text) {
      updatedText += c.text;
    }
    if (c.children) {
      return toSimpleTextHelper(c, updatedText);
    }
    return updatedText;
  }, text);
}

// For the current selection, walk up through the data model to find the
// immediate block parent.
export const getRootOfText = (editor: ReactEditor): Maybe<Node> => {

  if (editor.selection) {
    let [node, path] = Editor.node(editor, editor.selection);

    while (true) {

      if (node.text === undefined) {
        if (node.type !== undefined) {
          if ((schema as any)[node.type as string] !== undefined) {
            if ((schema as any)[node.type as string].isBlock) {
              return Maybe.just(node);
            }
            if (Editor.isEditor(node)) {
              return Maybe.nothing();
            }
          }
        }
      }

      if (path.length === 0) {
        return Maybe.nothing();
      }
      const [nextNode, nextPath] = Editor.parent(editor, path);
      node = nextNode;
      path = nextPath;
    }

  }
  return Maybe.nothing();

};
