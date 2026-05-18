import { parseBoolean } from '../../../utils/common';
import {
  htmlToPlainText,
  isRichLabelHtml,
  sanitizeRichLabelHtml,
} from '../../../utils/richOptionLabel';

const MCQ_DEFAULT_LABEL_SINGLE = 'Select one';
const MCQ_DEFAULT_LABEL_MULTI = 'Select all that apply';

export const resolveMcqInstructionalLabelHtml = (options: {
  showLabel: unknown;
  label: string | undefined;
  multipleSelection: boolean;
}): string | null => {
  if (!parseBoolean(options.showLabel as string | boolean | number)) {
    return null;
  }
  const raw = typeof options.label === 'string' ? options.label : '';
  const trimmed = raw.trim();
  const sanitizedAuthor = sanitizeRichLabelHtml(trimmed);

  // Any author-applied semantic markup (bold, italic, sup, sub): always show as stored — never swap for stock text.
  if (isRichLabelHtml(sanitizedAuthor)) {
    return sanitizedAuthor;
  }

  const plain = htmlToPlainText(sanitizedAuthor);
  if (
    plain === MCQ_DEFAULT_LABEL_SINGLE ||
    plain === MCQ_DEFAULT_LABEL_MULTI
  ) {
    return sanitizeRichLabelHtml(
      options.multipleSelection ? MCQ_DEFAULT_LABEL_MULTI : MCQ_DEFAULT_LABEL_SINGLE,
    );
  }
  return sanitizedAuthor;
};

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
