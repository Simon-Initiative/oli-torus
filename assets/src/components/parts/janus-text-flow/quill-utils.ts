import { CSSProperties } from 'react';
import Delta from 'quill-delta';

interface JanusMarkupNode {
  tag: string;
  href?: string;
  style: CSSProperties;
  children: JanusMarkupNode[];
  text?: string;
  customCssClass?: string;
  src?: string;
  alt?: string;
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

const convertFontSize = (fontSize: string, conversionType: 'px' | 'rem'): string => {
  const numericValue = parseFloat(fontSize);
  if (
    typeof fontSize !== 'string' ||
    isNaN(numericValue) ||
    numericValue > 20 ||
    (!fontSize.endsWith('px') && !fontSize.endsWith('rem'))
  ) {
    return `${fontSize}px`;
  }

  const baseFontSize = 16;
  const convertedValue =
    conversionType === 'px' ? numericValue * baseFontSize : numericValue / baseFontSize;
  return conversionType === 'px' ? `${convertedValue}px` : `${convertedValue}rem`;
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
      let size = attrs.fontSize;
      if (typeof size === 'number' || size.endsWith('px')) {
        size = `${convertFontSize(size.toString(), 'rem')}`;
      }
      nodeStyle.fontSize = size;
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
      if (typeof op.insert === 'object') {
        const imageDetails: any = op.insert;
        const child: JanusMarkupNode = {
          tag: 'img',
          style: {
            height: '100%',
            width: '100%',
          },
          alt: `${op?.attributes?.alt || ''}`,
          src: `${imageDetails.image}`,
          children: [],
        };
        node.children.push(child);
      } else if (typeof op.insert === 'string') {
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
          if (op.attributes.size) {
            let size = op.attributes.size;
            if (typeof op.attributes.size === 'number' || op.attributes.size.endsWith('px')) {
              size = `${convertFontSize(op.attributes.size.toString(), 'rem')}`;
            }
            style.fontSize = size;
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

  /* console.log('Q -> J', { doc, nodes }); */

  return nodes;
};

const processJanusChildren = (node: JanusMarkupNode, doc: Delta, parentAttrs: any = {}) => {
  const attrs: any = {};
  if (node.style?.fontWeight === 'bold') {
    attrs.bold = true;
  }
  if (node.style?.fontSize) {
    let size = node.style.fontSize;
    if (typeof size === 'number' || (!size.endsWith('px') && !size.endsWith('rem'))) {
      size = `${size}px`;
    } else if (typeof size === 'string' && size.endsWith('rem')) {
      size = `${convertFontSize(size, 'px')}`;
    }
    attrs.size = size;
  }
  if (node.style?.textDecoration) {
    if ((node.style.textDecoration as string).includes('underline')) {
      attrs.underline = true;
    }
    if ((node.style.textDecoration as string).includes('line-through')) {
      attrs.strike = true;
    }
  }
  if (node.style?.fontStyle === 'italic') {
    attrs.italic = true;
  }
  if (node.style?.color) {
    attrs.color = node.style.color;
  }
  if (node.style?.backgroundColor) {
    attrs.background = node.style.backgroundColor;
  }
  if (node.href) {
    attrs.link = node.href;
  }
  if (node.tag === 'sub') {
    attrs.script = 'sub';
  }
  if (node.tag === 'sup') {
    attrs.script = 'super';
  }

  if (node.children && node.children.length && node.children[0].tag === 'text') {
    const textNode = node.children[0];
    doc.insert(textNode.text as string, { ...parentAttrs, ...attrs });
  } else {
    node.children.forEach((child, index) => {
      const line = new Delta();
      if (blockTags.includes(child.tag) || child.style?.textAlign) {
        if ((child.tag === 'p' && index > 0) || child.tag !== 'p') {
          const lineAttrs: any = {};
          if (child.tag.startsWith('h')) {
            lineAttrs.header = parseInt(child.tag.substring(1), 10);
          }
          if (child.tag === 'blockquote') {
            lineAttrs.blockquote = true;
          }
          if (child.tag === 'ol') {
            parentAttrs.list = 'ordered';
          }
          if (child.tag === 'ul') {
            parentAttrs.list = 'bullet';
          }
          if (child.tag === 'li') {
            if (index === 0) {
              doc.insert('\n');
            }
            lineAttrs.list = parentAttrs.list;
          }
          if (child.style?.textAlign) {
            lineAttrs.align = child.style.textAlign;
          }
          if (child.tag === 'img') {
            doc.insert({ image: child.src });
          }
          line.insert('\n', lineAttrs);
        }
      }
      const childLine = processJanusChildren(child, new Delta(), attrs);
      doc = line.compose(childLine).compose(doc);
    });
  }
  return doc;
};

const blockTags = ['p', 'blockquote', 'ol', 'ul', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'img'];

export const convertJanusToQuill = (nodes: JanusMarkupNode[]) => {
  let doc = new Delta();
  const parentAttrs: any = {};
  nodes.forEach((node, index) => {
    const line = new Delta();
    if (blockTags.includes(node.tag) || node.style?.textAlign) {
      if ((node.tag === 'p' && index > 0) || node.tag !== 'p') {
        const attrs: any = {};
        if (node.tag.startsWith('h')) {
          attrs.header = parseInt(node.tag.substring(1), 10);
        }
        if (node.tag === 'blockquote') {
          attrs.blockquote = true;
        }
        if (node.tag === 'ol') {
          parentAttrs.list = 'ordered';
        }
        if (node.tag === 'ul') {
          parentAttrs.list = 'bullet';
        }
        if (node.tag === 'li') {
          attrs.list = parentAttrs.list;
        }
        if (node.style?.textAlign) {
          if (index === 1) {
            doc.insert('\n');
          }
          attrs.align = node.style.textAlign;
        }
        line.insert('\n', attrs);
      }
      if (node.tag === 'p' && index == 0) line.insert('\n');
    }
    const childLine = processJanusChildren(node, new Delta(), parentAttrs);
    doc = line.compose(childLine).compose(doc);
  });

  /*   console.log('J -> Q', { nodes, doc }); */

  return doc;
};
