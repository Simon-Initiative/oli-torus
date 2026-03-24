import sanitizeHtml, { IOptions } from 'sanitize-html';

const ALLOWED_TAGS = ['sup', 'sub', 'strong', 'em', 'b', 'i', 'br', 'p'];
const SEMANTIC_RICH_TAG_PATTERN = /<\s*(sup|sub|strong|em|b|i)\b/i;

const sanitizeOptions: IOptions = {
  allowedTags: ALLOWED_TAGS,
  allowedAttributes: {},
};

/**
 * Sanitize HTML for short Janus labels (dropdown options, future part labels).
 * Strips scripts, links, and any tag not in the allowlist.
 */
export function sanitizeRichLabelHtml(input: string): string {
  if (input == null || typeof input !== 'string') {
    return '';
  }
  return sanitizeHtml(input, sanitizeOptions);
}

/**
 * Plain text for aria-live, comparisons, and simple input previews.
 */
export function htmlToPlainText(html: string): string {
  const sanitized = sanitizeRichLabelHtml(html);
  if (typeof document !== 'undefined') {
    const div = document.createElement('div');
    div.innerHTML = sanitized;
    return (div.textContent || div.innerText || '').replace(/\s+/g, ' ').trim();
  }
  return sanitized.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
}

/**
 * True if sanitized content still contains semantic/formatting markup (needs non-native rendering).
 */
export function isRichLabelHtml(sanitized: string): boolean {
  return SEMANTIC_RICH_TAG_PATTERN.test(sanitized);
}

/**
 * True when any option should be shown in the rich custom dropdown (not native select).
 */
export function optionLabelsNeedRichDropdown(labels: string[] | undefined): boolean {
  if (!labels?.length) {
    return false;
  }
  return labels.some((l) => isRichLabelHtml(sanitizeRichLabelHtml(l || '')));
}

/**
 * Storage normalization:
 * - Keep sanitized HTML only when semantic rich tags exist (sup/sub/bold/italic).
 * - Otherwise store plain text (no <p> wrappers from Quill).
 */
export function normalizeRichLabelForStorage(input: string): string {
  const sanitized = sanitizeRichLabelHtml(input || '');
  if (isRichLabelHtml(sanitized)) {
    return sanitized;
  }
  return htmlToPlainText(sanitized);
}

/**
 * Resolve which option index (0-based) matches saved state. Prefers exact string match, then sanitized equality.
 */
export function findOptionIndexForSelectedItem(
  optionLabels: string[] | undefined,
  sSelectedItem: string,
): number {
  if (!optionLabels?.length || sSelectedItem === undefined || sSelectedItem === '') {
    return -1;
  }
  const exact = optionLabels.findIndex((l) => l === sSelectedItem);
  if (exact >= 0) {
    return exact;
  }
  const sanitizedTarget = sanitizeRichLabelHtml(sSelectedItem);
  return optionLabels.findIndex((l) => sanitizeRichLabelHtml(l) === sanitizedTarget);
}
