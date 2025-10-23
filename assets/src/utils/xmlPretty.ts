// xmlPretty.ts
export type PrettyXMLOptions = {
  indent?: number; // spaces per indent level (default: 2)
  inlineTextMax?: number; // max length to inline text nodes (default: 60)
};

export function prettyPrintXml(xml: string, opts: PrettyXMLOptions = {}): string {
  const indent = opts.indent ?? 2;
  const inlineTextMax = opts.inlineTextMax ?? 60;

  // Prefer DOMParser if present (browser/deno); fall back otherwise.
  const hasDOMParser = typeof (globalThis as any).DOMParser === 'function';
  if (hasDOMParser) {
    try {
      const doc = parseXml(xml);
      return serializeNode(doc, { indent, inlineTextMax }).trimEnd();
    } catch {
      // fall through to naive formatter
    }
  }
  return naiveFormat(xml, indent);
}

/* -------------------- XML helpers -------------------- */

function parseXml(xml: string): Document {
  const parser = new DOMParser();
  const doc = parser.parseFromString(xml, 'text/xml');

  // Detect parse errors via <parsererror>
  const pe = doc.getElementsByTagName('parsererror')[0];
  if (pe) {
    const msg = pe.textContent?.replace(/\s+/g, ' ').trim() || 'XML parse error';
    throw new Error(msg);
  }
  return doc;
}

function serializeNode(
  node: Node,
  cfg: { indent: number; inlineTextMax: number },
  depth = 0,
): string {
  const pad = (n: number) => ' '.repeat(cfg.indent * n);

  switch (node.nodeType) {
    case Node.DOCUMENT_NODE: {
      const doc = node as Document;
      let s = '';
      // TypeScript Document interface doesn't include xmlVersion/xmlEncoding
      const xmlDoc = doc as any;
      if (xmlDoc.xmlVersion) {
        s += `<?xml version="${xmlDoc.xmlVersion}"${
          xmlDoc.xmlEncoding ? ` encoding="${xmlDoc.xmlEncoding}"` : ''
        }?>\n`;
      }
      doc.childNodes.forEach((child) => (s += serializeNode(child, cfg, 0)));
      return s;
    }

    case Node.DOCUMENT_TYPE_NODE:
      return pad(depth) + serializeDoctype(node as DocumentType) + '\n';

    case Node.ELEMENT_NODE: {
      const el = node as Element;
      const attrs = Array.from(el.attributes)
        .map((a) => `${a.name}="${escapeAttr(a.value)}"`)
        .join(' ');
      const open = attrs.length ? `<${el.tagName} ${attrs}>` : `<${el.tagName}>`;

      const children = Array.from(el.childNodes);
      if (children.length === 0) {
        const sc = attrs.length ? `<${el.tagName} ${attrs} />` : `<${el.tagName} />`;
        return pad(depth) + sc + '\n';
      }

      const textNodes = children.filter((c) => c.nodeType === Node.TEXT_NODE) as Text[];
      const nonTextNodes = children.filter((c) => c.nodeType !== Node.TEXT_NODE);

      // Inline single short text node
      if (nonTextNodes.length === 0 && textNodes.length === 1) {
        const raw = textNodes[0].nodeValue ?? '';
        const trimmed = raw.trim();
        if (trimmed.length <= cfg.inlineTextMax && !trimmed.includes('\n')) {
          return (
            pad(depth) + open.replace(/>$/, '') + '>' + escapeText(trimmed) + `</${el.tagName}>\n`
          );
        }
      }

      // Block with children
      let out = pad(depth) + open + '\n';
      for (const child of children) out += serializeNode(child, cfg, depth + 1);
      out += pad(depth) + `</${el.tagName}>\n`;
      return out;
    }

    case Node.TEXT_NODE: {
      const text = (node.nodeValue ?? '').replace(/\s+/g, ' ').trim();
      if (!text) return '';
      return pad(depth) + escapeText(text) + '\n';
    }

    case Node.CDATA_SECTION_NODE:
      return pad(depth) + '<![CDATA[' + (node.nodeValue ?? '') + ']]>\n';

    case Node.COMMENT_NODE: {
      const body = (node.nodeValue ?? '').replace(/\s+$/g, '');
      return pad(depth) + `<!-- ${body} -->\n`;
    }

    case Node.PROCESSING_INSTRUCTION_NODE: {
      const pi = node as ProcessingInstruction;
      return pad(depth) + `<?${pi.target} ${pi.data}?>\n`;
    }

    default:
      return '';
  }
}

function serializeDoctype(dt: DocumentType): string {
  if (dt.publicId) return `<!DOCTYPE ${dt.name} PUBLIC "${dt.publicId}" "${dt.systemId}">`;
  if (dt.systemId) return `<!DOCTYPE ${dt.name} SYSTEM "${dt.systemId}">`;
  return `<!DOCTYPE ${dt.name}>`;
}

function escapeText(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
}
function escapeAttr(s: string) {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

/**
 * Minimal fallback formatter for invalid XML (or when DOMParser is unavailable).
 * Not XML-aware (ignores CDATA/comments nuances) but yields readable indentation.
 */
function naiveFormat(xml: string, indent: number) {
  const step = ' '.repeat(indent);
  const cleaned = xml.replace(/\r?\n/g, '').replace(/>\s+</g, '><').trim();
  const tokens = cleaned.split(/(<[^>]+>)/g).filter(Boolean);

  let pad = 0;
  return tokens
    .map((tok) => {
      if (/^<\/[^>]+>/.test(tok)) pad = Math.max(pad - 1, 0);
      const line = step.repeat(pad) + tok;
      if (/^<[^!?/][^>]*[^/]>$/.test(tok)) pad += 1; // opening tag (not PI/doctype/self-closing)
      return line;
    })
    .join('\n');
}
