import Delta from 'quill-delta';

export const convertQuillToJanus = (delta: Delta) => {
  const doc = new Delta().compose(delta);
  const nodes: any[] = [];
  doc.eachLine((line, attrs) => {
    const nodeStyle: any = {};
    // TODO: handle line level attributes
    if (attrs.fontSize) {
      nodeStyle.fontSize = attrs.fontSize;
    }
    const node: { tag: string; style: any; children: any[] } = {
      tag: 'p',
      style: {},
      children: [],
    };
    line.forEach((op) => {
      if (typeof op.insert === 'string') {
        // TODO: handle attributes
        const style: any = {};
        if (op.attributes) {
          if (op.attributes.bold) {
            style.fontWeight = 'bold';
          }
          if (op.attributes.italic) {
            style.fontStyle = 'italic';
          }
          if (op.attributes.underline) {
            style.textDecoration = 'underline';
          }
        }
        const child = {
          tag: 'span',
          style,
          children: [
            {
              tag: 'text',
              text: op.insert,
              children: [],
            },
          ],
        };
        node.children.push(child);
      }
    });
    nodes.push(node);
  });

  return nodes;
};

export const convertJanusToQuill = (nodes: any[]) => {
  let doc = new Delta();
  nodes.forEach((node, index) => {
    if (node.tag === 'p') {
      const line = new Delta();
      if (index > 0) {
        line.insert('\n');
      }
      node.children.forEach((child: any) => {
        if (child.tag === 'span') {
          const text = child.children.find((c: any) => c.tag === 'text');
          const attrs: any = {};
          if (child.style.fontWeight === 'bold') {
            attrs.bold = true;
          }
          if (child.style.textDecoration === 'underline') {
            attrs.underline = true;
          }
          if (text) {
            line.insert(text.text, attrs);
          }
        }
      });
      doc = line.compose(doc);
    }
  });
  console.log('***********', doc.ops);
  return doc;
};
