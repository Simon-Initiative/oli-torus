import { Node, Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { Marks, schema } from 'data/content/model';
import { Maybe } from 'tsmonad';

// Returns true if a text node contains at least one mark
export function hasMark(textNode: Text) : boolean {
  return Object.keys(textNode).some(k => k in Marks);
}

// Extracts the text from a hierarchy of nodes
export function toSimpleText(node: Node) : string {
  return toSimpleTextHelper(node, '');
}

function toSimpleTextHelper(node: Node, text: string) : string {

  return node.children.reduce((p: string, c : any) => {
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
export const getRootOfText = (editor: ReactEditor) : Maybe<Node> => {

  if (editor.selection !== null) {
    let [node, path] = Editor.node(editor, editor.selection);

    while (node.text !== undefined || !(schema as any)[node.type].isBlock) {
      const [nextNode, nextPath] = Editor.parent(editor, path);
      node = nextNode;
      path = nextPath;
    }

    return Maybe.just(node);

  }
  return Maybe.nothing();

};