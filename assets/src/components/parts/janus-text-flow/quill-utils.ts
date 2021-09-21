import Delta from 'quill-delta';
import { CSSProperties } from 'react';

interface JanusMarkupNode {
  tag: string;
  href?: string;
  style: CSSProperties;
  children: JanusMarkupNode[];
  text?: string;
  customCssClass?: string;
}

const appendToStringProperty = (append: string, str?: string) => {
  if (!str) {
    return append;
  }
  return `${str} ${append}`;
};

const convertFontName = (fontCode: string) => {
  const result = fontCode
    .split('-')
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(' ');
  return result;
};

export const convertQuillToJanus = (delta: Delta) => {
  const doc = new Delta().compose(delta);
  const nodes: JanusMarkupNode[] = [];
  let listParent: JanusMarkupNode | null = null;
  doc.eachLine((line, attrs) => {
    const nodeStyle: CSSProperties = {};

    const node: JanusMarkupNode = {
      tag: 'p',
      style: nodeStyle,
      children: [],
    };

    if (attrs.fontSize) {
      nodeStyle.fontSize = attrs.fontSize;
    }

    if (attrs.indent) {
      nodeStyle.paddingLeft = `${attrs.indent * 3}em`;
      node.customCssClass = appendToStringProperty(
        `ql-indent-${attrs.indent}`,
        node.customCssClass,
      );
    }

    if (attrs.align) {
      nodeStyle.textAlign = attrs.align;
    }

    if (attrs.list) {
      if (!listParent) {
        listParent = {
          tag: attrs.list === 'ordered' ? 'ol' : 'ul',
          style: {},
          children: [],
        };
        nodes.push(listParent);
      }
      node.tag = 'li';
    } else if (listParent) {
      listParent = null;
    }

    if (attrs.blockquote) {
      node.tag = 'blockquote';
    }

    if (attrs.header) {
      node.tag = `h${attrs.header}`;
    }

    line.forEach((op) => {
      if (typeof op.insert === 'string') {
        const style: any = {};
        if (op.attributes) {
          if (op.attributes.font) {
            style.fontFamily = convertFontName(op.attributes.font);
          }
          if (op.attributes.bold) {
            style.fontWeight = 'bold';
          }
          if (op.attributes.italic) {
            style.fontStyle = 'italic';
          }
          if (op.attributes.underline) {
            style.textDecoration = appendToStringProperty('underline', style.textDecoration);
          }
          if (op.attributes.strike) {
            style.textDecoration = appendToStringProperty('line-through', style.textDecoration);
          }
          if (op.attributes.color) {
            style.color = op.attributes.color;
          }
          if (op.attributes.background) {
            style.backgroundColor = op.attributes.background;
          }
        }
        const child: JanusMarkupNode = {
          tag: 'span',
          style,
          children: [
            {
              tag: 'text',
              style: {},
              text: op.insert,
              children: [],
            },
          ],
        };
        if (style.fontFamily) {
          child.customCssClass = appendToStringProperty(
            `ql-font-${op.attributes?.font}`,
            child.customCssClass,
          );
        }
        if (op.attributes?.script) {
          if (op.attributes.script === 'sub') {
            child.tag = 'sub';
          }
          if (op.attributes.script === 'super') {
            child.tag = 'sup';
          }
        }
        if (op.attributes?.link) {
          child.tag = 'a';
          child.href = op.attributes.link;
        }
        node.children.push(child);
      }
    });

    if (listParent) {
      listParent.children.push(node);
    } else {
      nodes.push(node);
    }
  });

  // console.log('J -> Q', { doc, nodes });

  return nodes;
};

/* const processJanusChildren = (node: JanusMarkupNode, line: Delta) => {
  node.children.forEach((child) => {
    if (child.tag === 'span') {
      const text = child.children.find((c) => c.tag === 'text');
      const attrs: any = {};
      if (child.style.fontWeight === 'bold') {
        attrs.bold = true;
      }
      if (child.style.textDecoration === 'underline') {
        attrs.underline = true;
      }
      if (child.style.fontStyle === 'italic') {
        attrs.italic = true;
      }
      if (child.style.color) {
        attrs.color = child.style.color;
      }
      if (text) {
        line.insert(text.text as string, attrs);
      }
    }
  });
};

const blockTags = ['p', 'blockquote', 'ol', 'ul'];

export const convertJanusToQuill = (nodes: JanusMarkupNode[]) => {
  let doc = new Delta();
  nodes.forEach((node, index) => {
    const line = new Delta();
    if (blockTags.includes(node.tag)) {
      if (index > 0) {
        line.insert('\n');
      }
    }
    processJanusChildren(node, line);
    doc = line.compose(doc);
  });

  console.log('J -> Q', { nodes, doc });

  return doc;
}; */
