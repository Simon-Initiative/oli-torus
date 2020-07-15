import { Node } from 'slate';

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
