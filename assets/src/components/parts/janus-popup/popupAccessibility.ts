import { htmlToPlainText } from 'utils/richOptionLabel';

/** Resolve the popup dialog name using its visible label, description, then default. */
export function getPopupAccessibleName(
  labelText: string | undefined,
  shouldShowLabel: boolean,
  description?: string,
): string {
  return (
    (shouldShowLabel && htmlToPlainText(labelText ?? '')) ||
    description?.trim() ||
    'Additional Information'
  );
}

/**
 * Build a single text description for informational popups. Keep inline text
 * together (including sub/superscripts), separate blocks, and include image alt
 * text. Interactive content must keep its original accessible structure.
 */
export function getPopupDescriptionText(content: HTMLElement): string | null {
  if (
    content.querySelector(
      'a[href], button, input, select, textarea, iframe, [tabindex], [contenteditable="true"]',
    )
  ) {
    return null;
  }

  const read = (node: Node): string => {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent ?? '';
    }
    if (!(node instanceof HTMLElement)) {
      return '';
    }
    if (
      node.hidden ||
      node.getAttribute('aria-hidden') === 'true' ||
      ['SCRIPT', 'STYLE', 'TEMPLATE'].includes(node.tagName)
    ) {
      return '';
    }

    const style = getComputedStyle(node);
    if (style.display === 'none' || ['hidden', 'collapse'].includes(style.visibility)) {
      return '';
    }
    if (node.tagName === 'IMG') {
      return ` ${node.getAttribute('aria-label') ?? node.getAttribute('alt') ?? ''} `;
    }
    if (node.tagName === 'BR') {
      return ' ';
    }

    const text = Array.from(node.childNodes).map(read).join('');
    const isBlock = ['block', 'flex', 'grid', 'list-item', 'table-row'].includes(style.display);
    return isBlock ? ` ${text} ` : text;
  };

  return read(content).replace(/\s+/g, ' ').trim();
}
