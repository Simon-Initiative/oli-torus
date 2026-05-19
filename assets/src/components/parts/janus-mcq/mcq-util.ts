import { parseBoolean } from '../../../utils/common';
import {
  htmlToPlainText,
  isRichLabelHtml,
  sanitizeRichLabelHtml,
} from '../../../utils/richOptionLabel';

export const MCQ_DEFAULT_LABEL_SINGLE = 'Select one';
export const MCQ_DEFAULT_LABEL_MULTI = 'Select all that apply';

/** True when label is exactly the built-in single/multi prompt (plain), including stored defaults on new parts. */
export const isMcqStockInstructionalLabel = (label: string | undefined): boolean => {
  const raw = typeof label === 'string' ? label : '';
  const plain = htmlToPlainText(sanitizeRichLabelHtml(raw.trim()));
  return plain === MCQ_DEFAULT_LABEL_SINGLE || plain === MCQ_DEFAULT_LABEL_MULTI;
};

/** Partial custom patch when multipleSelection changes in authoring (avoids full-model overwrite). */
export const buildMcqMultipleSelectionConfigurePatch = (
  label: string | undefined,
  multipleSelection: boolean,
): { multipleSelection: boolean; label?: string } => {
  const patch: { multipleSelection: boolean; label?: string } = { multipleSelection };
  // Do not write stock text when label is empty (legacy MCQs); only sync explicit stock phrases.
  if (isMcqStockInstructionalLabel(label)) {
    patch.label = multipleSelection ? MCQ_DEFAULT_LABEL_MULTI : MCQ_DEFAULT_LABEL_SINGLE;
  }
  return patch;
};

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
  // Legacy MCQs: showLabel may be true with no label — do not invent stock text.
  if (!trimmed) {
    return null;
  }
  const sanitizedAuthor = sanitizeRichLabelHtml(trimmed);

  // Any author-applied semantic markup (bold, italic, sup, sub): always show as stored — never swap for stock text.
  if (isRichLabelHtml(sanitizedAuthor)) {
    return sanitizedAuthor;
  }

  const plain = htmlToPlainText(sanitizedAuthor);
  if (plain === MCQ_DEFAULT_LABEL_SINGLE || plain === MCQ_DEFAULT_LABEL_MULTI) {
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
