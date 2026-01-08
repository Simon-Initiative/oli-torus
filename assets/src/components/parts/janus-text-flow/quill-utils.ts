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

// Shared font mapping: maps font codes (lowercase with hyphens) to CSS font-family values with fallbacks
// This ensures fonts render correctly in both authoring (via CSS classes) and delivery (via inline styles)
export const fontFamilyMapping: Record<string, string> = {
  // New fonts
  'open-sans': '"Open Sans", "Helvetica Neue", Arial, sans-serif',
  aleo: '"Aleo", Georgia, serif',
  'courier-prime': '"Courier Prime", "Courier New", monospace',
  brawler: '"Brawler", Georgia, serif',
  montserrat: '"Montserrat", "Helvetica Neue", Arial, sans-serif',
  'patrick-hand': '"Patrick Hand", "Comic Sans MS", cursive',
  // Old fonts (for backward compatibility)
  initial: 'Times, "Times New Roman", serif',
  arial: 'Arial, "Helvetica Neue", Helvetica, sans-serif',
  'times-new-roman': '"Times New Roman", Times, serif',
  'sans-serif': 'Arial, "Helvetica Neue", Helvetica, sans-serif',
};

/**
 * Converts a font display name to a font code (lowercase with hyphens).
 * Example: "Open Sans" -> "open-sans"
 * @param font - The font display name
 * @returns The font code
 */
export const getFontName = (font: string) => {
  return font.toLowerCase().replace(/\s/g, '-');
};

/**
 * Converts a font code to a display name (capitalize words).
 * Example: "open-sans" -> "Open Sans"
 * @param fontCode - The font code
 * @returns The font display name
 */
const getFontDisplayName = (fontCode: string): string => {
  return fontCode
    .split('-')
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(' ');
};

/**
 * Gets the list of supported fonts (new fonts only, excluding old fonts for backward compatibility).
 * This ensures consistency between the font mapping and the supported fonts list.
 * @returns Array of font display names (e.g., ['Open Sans', 'Aleo', ...])
 */
export const getSupportedFonts = (): string[] => {
  // Old fonts to exclude (for backward compatibility only)
  const oldFonts = ['initial', 'arial', 'times-new-roman', 'sans-serif'];

  return Object.keys(fontFamilyMapping)
    .filter((fontCode) => !oldFonts.includes(fontCode))
    .map((fontCode) => getFontDisplayName(fontCode));
};

const convertFontName = (fontCode: string) => {
  // First check if we have a mapping for this font code
  if (fontFamilyMapping[fontCode]) {
    return fontFamilyMapping[fontCode];
  }
  // Fallback to converting code to display name (for backward compatibility)
  const result = fontCode
    .split('-')
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(' ');
  return result;
};

/**
 * Reverse maps a CSS font-family string back to a Quill font code.
 * This is used when loading content from Janus markup to restore the font selection in the editor.
 * @param fontFamily - The CSS font-family string (e.g., '"Open Sans", "Helvetica Neue", Arial, sans-serif')
 * @returns The font code (e.g., "open-sans") or null if no match is found
 */
const convertFontFamilyToCode = (fontFamily: string): string | null => {
  if (!fontFamily || typeof fontFamily !== 'string') {
    return null;
  }

  // First, try to find an exact or partial match in fontFamilyMapping
  for (const [fontCode, cssValue] of Object.entries(fontFamilyMapping)) {
    // Check if the fontFamily string contains the CSS value (for partial matches)
    if (fontFamily.includes(cssValue) || cssValue.includes(fontFamily)) {
      return fontCode;
    }
    // Also check if the first font name in the CSS value matches
    // Extract the first quoted font name from CSS value (e.g., "Open Sans" from '"Open Sans", ...')
    const firstFontMatch = cssValue.match(/^"([^"]+)"/);
    if (firstFontMatch && fontFamily.includes(firstFontMatch[1])) {
      return fontCode;
    }
  }

  // If no mapping match, try to extract font name from the CSS string
  // Pattern: "Font Name" or 'Font Name' or just Font Name
  const quotedMatch = fontFamily.match(/^["']([^"']+)["']/);
  if (quotedMatch) {
    const fontName = quotedMatch[1];
    // Convert to font code format using shared utility
    const fontCode = getFontName(fontName);
    // Check if this font code exists in our mapping (for backward compatibility)
    if (fontFamilyMapping[fontCode]) {
      return fontCode;
    }
    // For old fonts that might not be in mapping, return the converted code anyway
    // This handles cases like "Arial" -> "arial" which might work with Quill
    return fontCode;
  }

  // Try to extract font name without quotes (e.g., "Arial" as a simple string)
  const simpleMatch = fontFamily.match(/^([^,]+)/);
  if (simpleMatch) {
    const fontName = simpleMatch[1].trim();
    // Convert to font code format using shared utility
    const fontCode = getFontName(fontName);
    if (fontFamilyMapping[fontCode]) {
      return fontCode;
    }
    return fontCode;
  }

  return null;
};

const maxmimumFontSizeAvailableForSelection = 32;
const convertFontSize = (fontSize: string, conversionType: 'px' | 'rem'): string => {
  const numericValue = parseFloat(fontSize);
  // With the new REM-based font size rendering, the selectable font sizes now range from 14px to 32px.
  // Font sizes above this range are not converted, as they belong to existing migrated lessons that should remain unaffected by these changes.
  if (
    typeof fontSize !== 'string' ||
    isNaN(numericValue) ||
    numericValue > maxmimumFontSizeAvailableForSelection ||
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
        const imageValue = imageDetails?.image;
        const src = typeof imageValue === 'string' ? imageValue : imageValue.src;
        const child: JanusMarkupNode = {
          tag: 'img',
          style: {
            height: '100%',
            width: '100%',
          },
          alt: `${op?.attributes?.alt || ''}`,
          src: `${src}`,
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

  // Extract font code from customCssClass or fontFamily to restore font selection in editor
  // Priority 1: Check customCssClass for ql-font-{fontCode} pattern
  if (node.customCssClass) {
    const fontClassMatch = node.customCssClass.match(/ql-font-([a-z0-9-]+)/);
    if (fontClassMatch && fontClassMatch[1]) {
      const fontCode = fontClassMatch[1];
      // Verify the font code exists in our mapping (for validation)
      if (fontFamilyMapping[fontCode]) {
        attrs.font = fontCode;
      } else {
        // For backward compatibility, still use the font code even if not in mapping
        // This handles old fonts that might not be in the current mapping
        attrs.font = fontCode;
      }
    }
  }

  // Priority 2: If not found in customCssClass, try to reverse-map from fontFamily
  if (!attrs.font && node.style?.fontFamily) {
    const fontCode = convertFontFamilyToCode(node.style.fontFamily as string);
    if (fontCode) {
      attrs.font = fontCode;
    }
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
            doc.insert({ image: child.src, alt: child.alt });
          }
          line.insert('\n', lineAttrs);
        }
      }
      const childLine = processJanusChildren(child, new Delta(), { ...parentAttrs, ...attrs });
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
