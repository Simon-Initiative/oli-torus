// SS assumes the unstyled "text" of the label is the text value
// there should only be one node in a label text, but we'll concat them jic
export const getNodeText = (node: any): any => {
  if (Array.isArray(node)) {
    return node.reduce((txt, newNode) => (txt += getNodeText(newNode)), '');
  }
  let nodeText = node.text || '';
  nodeText += node.children.reduce((childrenText: any, childNode: any) => {
    let txt = childrenText;
    txt += getNodeText(childNode);
    return txt;
  }, '');
  return nodeText;
};
