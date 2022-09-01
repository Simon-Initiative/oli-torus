import { normalizeHref } from './utils';

import {
  TableData,
  TableRow,
  ListItem,
  OrderedList,
  UnorderedList,
  Webpage,
  Hyperlink,
  Paragraph,
  InputRef,
  Popup,
  Figure,
  Table,
  YouTube,
  ImageBlock,
  Audio,
  Blockquote,
  HeadingOne,
  HeadingTwo,
  Citation,
  ImageInline,
  CodeV2,
  FormulaBlock,
  FormulaInline,
  FormulaSubTypes,
  Callout,
  CalloutInline,
  Video,
  DefinitionMeaning,
  DefinitionPronunciation,
  DefinitionTranslation,
  Definition,
  AllModelElements,
  Dialog,
  DialogLine,
  DialogSpeaker,
} from 'data/content/model/elements/types';
import { Text } from 'slate';
import guid from 'utils/guid';

function create<E extends AllModelElements>(params: Partial<E>): E {
  return {
    id: guid(),
    children: [{ text: '' }],
    ...params,
  } as E;
}

export const Model = {
  h1: (text = '') => create<HeadingOne>({ type: 'h1', children: [{ text }] }),

  h2: (text = '') => create<HeadingTwo>({ type: 'h2', children: [{ text }] }),

  td: (text: string) => create<TableData>({ type: 'td', children: [Model.p(text)] }),

  tr: (children: TableData[]) => create<TableRow>({ type: 'tr', children }),

  table: (children: TableRow[]) => create<Table>({ type: 'table', children }),

  li: () => create<ListItem>({ type: 'li' }),

  ol: () => create<OrderedList>({ type: 'ol', children: [Model.li()] }),

  ul: () => create<UnorderedList>({ type: 'ul', children: [Model.li()] }),

  video: () => create<Video>({ type: 'video', src: [] }),

  youtube: (src?: string) => create<YouTube>({ type: 'youtube', src }),

  callout: (text = '') => create<Callout>({ type: 'callout', children: [Model.p(text)] }),
  calloutInline: (text = '') =>
    create<CalloutInline>({ type: 'callout_inline', children: [{ text }] }),

  dialogSpeaker: (name: string) => ({ name, image: '', id: guid() }),

  dialogLine: (speaker: string) =>
    create<DialogLine>({ type: 'dialog_line', speaker, children: [Model.p()] }),

  dialog: (title = '') =>
    create<Dialog>({
      type: 'dialog',
      title,
      lines: [],
      speakers: [Model.dialogSpeaker('Speaker #1'), Model.dialogSpeaker('Speaker #2')],
    }),

  figure: (title = '') => create<Figure>({ type: 'figure', title, children: [Model.p()] }),

  formula: (subtype: FormulaSubTypes = 'latex', src = '1 + 2 = 3') =>
    create<FormulaBlock>({ type: 'formula', src, subtype }),

  formulaInline: (subtype: FormulaSubTypes = 'latex', src = '1 + 2 = 3') =>
    create<FormulaInline>({ type: 'formula_inline', src, subtype }),

  webpage: (src?: string) => create<Webpage>({ type: 'iframe', src }),

  link: (href = '') => create<Hyperlink>({ type: 'a', href: normalizeHref(href), target: 'self' }),

  cite: (text = '', bibref: number) =>
    create<Citation>({ type: 'cite', bibref: bibref, children: [{ text }] }),

  image: (src?: string) => create<ImageBlock>({ type: 'img', src, display: 'block' }),

  imageInline: (src?: string) => create<ImageInline>({ type: 'img_inline', src }),

  audio: (src?: string) => create<Audio>({ type: 'audio', src }),

  p: (children?: (InputRef | Text)[] | string) => {
    if (!children) return create<Paragraph>({ type: 'p' });
    if (Array.isArray(children)) return create<Paragraph>({ type: 'p', children });
    return create<Paragraph>({ type: 'p', children: [{ text: children }] });
  },

  blockquote: () =>
    create<Blockquote>({
      type: 'blockquote',
    }),

  code: (code = '') =>
    create<CodeV2>({
      type: 'code',
      code,
      language: 'Text',
    }),

  inputRef: () => create<InputRef>({ type: 'input_ref' }),

  popup: () =>
    create<Popup>({
      type: 'popup',
      trigger: 'hover',
      content: [Model.p()],
    }),

  definitionMeaning: (overrides?: Partial<DefinitionMeaning>) =>
    create<DefinitionMeaning>({ type: 'meaning', children: [Model.p()], ...overrides }),
  definitionPronunciation: (overrides?: Partial<DefinitionPronunciation>) =>
    create<DefinitionPronunciation>({ type: 'pronunciation', children: [Model.p()], ...overrides }),
  definitionTranslation: (overrides?: Partial<DefinitionTranslation>) =>
    create<DefinitionTranslation>({ type: 'translation', children: [Model.p()], ...overrides }),
  definition: (overrides?: Partial<Definition>) =>
    create<Definition>({
      type: 'definition',
      term: 'Term',
      meanings: [Model.definitionMeaning({})],
      translations: [],
      ...overrides,
    }),
};
