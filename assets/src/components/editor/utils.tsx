import { Node } from 'slate';
import { Marks } from 'data/content/model';

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
