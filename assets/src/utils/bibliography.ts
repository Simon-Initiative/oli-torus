const Cite = (window as any).cite;

/**
 * Normalize stored bibliography content into a value citation-js can consume.
 * Supports current CSL-array shape as well as legacy bibtex-only payloads
 * produced by scenario seeds.
 */
export function toCiteInput(raw: any) {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    if ((trimmed.startsWith('{') || trimmed.startsWith('[')) && trimmed.endsWith('}')) {
      try {
        return JSON.parse(trimmed);
      } catch (e) {
        // fall through to raw string
      }
    }
    if ((trimmed.startsWith('[') || trimmed.startsWith('{')) && trimmed.endsWith(']')) {
      try {
        return JSON.parse(trimmed);
      } catch (e) {
        // fall through
      }
    }
    return raw;
  }

  if (typeof raw === 'object') {
    const data: any = raw as any;

    if (typeof data.bibtex === 'string') return data.bibtex;
    if (Array.isArray(data.csl)) return data.csl;
    if (data.type) return [data];
  }

  return raw;
}

/**
 * Extracts the CSL JSON array from any supported bibliography payload.
 * Returns an empty array when the payload cannot be parsed.
 */
export function toCslArray(raw: any): any[] {
  try {
    const cite = new Cite(toCiteInput(raw));
    const csl = cite.get({
      format: 'string',
      type: 'json',
      style: 'csl',
      lang: 'en-US',
    });

    const parsed = JSON.parse(csl);

    if (Array.isArray(parsed)) return parsed;
    if (parsed) return [parsed];
  } catch (e) {
    // fall through and return []
  }

  return [];
}
