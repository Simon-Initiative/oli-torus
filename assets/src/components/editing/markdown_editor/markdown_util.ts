import { AllModelElements, AllModelTypes } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';

export const MarkdownCompatibleTypes: AllModelTypes[] = [
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'ul',
  'ol',
  'code',
  'blockquote',
  'img',
  'tr',
  'th',
  'td',
  'tr',
  'table',
];

export const MarkdownCompatibleMarks: string[] = ['strong', 'em', 'strikethrough', 'code'];

const translations: Record<string, string> = {
  em: 'italic',
  strong: 'bold',
  di: 'Description List',
  iframe: 'Webpage (iFrame)',
};

const hasType = (node: AllModelElements | FormattedText): node is AllModelElements =>
  'type' in node;

const hasText = (node: AllModelElements | FormattedText): node is FormattedText => 'text' in node;

export const getMarkdownWarnings = (model: (AllModelElements | FormattedText)[]): string[] => {
  const warnings: string[] = [];

  model?.filter(hasType).forEach((element) => {
    if (!MarkdownCompatibleTypes.includes(element.type)) {
      warnings.push(element.type);
    }
  });

  model?.filter(hasText).forEach((element) => {
    const marks = Object.keys(element || []).filter(
      (mark) => mark !== 'text' && mark !== 'id' && mark !== 'type',
    );

    marks.forEach((mark) => {
      if (!MarkdownCompatibleMarks.includes(mark)) {
        warnings.push(mark);
      }
    });
  });

  model?.forEach((element) => {
    if ('children' in element) {
      warnings.push(...getMarkdownWarnings(element.children));
    }
  });

  const uniqueWarnings = [...new Set(warnings)];
  return Array.from(uniqueWarnings).map((warning) => capitalize(translations[warning] || warning));
};

const capitalize = (str: string): string => str.charAt(0).toUpperCase() + str.slice(1);

export const getDefaultEditor = (): EditorType => {
  return window.preferences?.editor || DEFAULT_EDITOR;
};

export const setDefaultEditor = (editor: EditorType) => {
  window.preferences = {
    editor,
  };
};

declare global {
  interface Window {
    preferences?: {
      editor: EditorType;
    };
  }
}
