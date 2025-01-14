import {
  AllModelElements,
  Audio,
  Blockquote,
  Callout,
  CalloutInline,
  Citation,
  CodeLine,
  CodeV1,
  CodeV2,
  CommandButton,
  Conjugation,
  Definition,
  DefinitionMeaning,
  DefinitionTranslation,
  DescriptionList,
  DescriptionListDefinition,
  DescriptionListTerm,
  Dialog,
  DialogLine,
  ECLRepl,
  Figure,
  Foreign,
  FormulaBlock,
  FormulaInline,
  FormulaSubTypes,
  HeadingOne,
  HeadingTwo,
  Hyperlink,
  ImageBlock,
  ImageInline,
  InputRef,
  ListChildren,
  ListItem,
  ModelElement,
  OrderedList,
  PageLink,
  Paragraph,
  Popup,
  Pronunciation,
  Table,
  TableCell,
  TableConjugation,
  TableData,
  TableHeader,
  TableRow,
  TriggerBlock,
  UnorderedList,
  Video,
  Webpage,
  YouTube,
} from 'data/content/model/elements/types';
import guid from 'utils/guid';
import { normalizeHref } from './utils';

// removeUndefined({a: 1, b: undefined}) = {a: 1}
export const removeUndefined = (obj: Record<string, any>): unknown => {
  return Object.entries(obj)
    .filter(([_, v]) => v !== undefined)
    .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {});
};

function create<E extends AllModelElements>(params: Partial<E>): E {
  return removeUndefined({
    id: guid(),
    children: [{ text: '' }],
    ...params,
  }) as E;
}

export const emptyChildren = (element: AllModelElements) =>
  ({
    ...element,
    children: [],
  } as ModelElement);

export const Model = {
  h1: (text = '') => create<HeadingOne>({ type: 'h1', children: [{ text }] }),

  h2: (text = '') => create<HeadingTwo>({ type: 'h2', children: [{ text }] }),

  th: (text: string) => create<TableHeader>({ type: 'th', children: [Model.p(text)] }),

  td: (text: string) => create<TableData>({ type: 'td', children: [Model.p(text)] }),

  tc: (text: string) => create<TableConjugation>({ type: 'tc', children: [Model.p(text)] }),

  tr: (children: (TableHeader | TableCell)[]) => create<TableRow>({ type: 'tr', children }),

  table: (children: TableRow[] = []) => create<Table>({ type: 'table', children }),

  li: (text: string | ListItem['children'] = '') => {
    if (typeof text === 'string') {
      return create<ListItem>({ type: 'li', children: [Model.p(text)] });
    }

    return create<ListItem>({ type: 'li', children: text });
  },

  ol: (children?: OrderedList['children']) =>
    create<OrderedList>({ type: 'ol', children: children || [Model.li()] }),

  ul: (children?: ListChildren | undefined) =>
    create<UnorderedList>({ type: 'ul', children: children || [Model.li()] }),

  dt: () => create<DescriptionListTerm>({ type: 'dt', children: [Model.p([{ text: 'A term' }])] }),
  dd: () =>
    create<DescriptionListDefinition>({
      type: 'dd',
      children: [Model.p([{ text: 'A definition' }])],
    }),
  dl: (children: (DescriptionListDefinition | DescriptionListTerm)[] | null = null) =>
    create<DescriptionList>({
      type: 'dl',
      title: [Model.p([{ text: 'Description Title' }])],
      items: children || [Model.dt(), Model.dd()],
    }),

  video: () => create<Video>({ type: 'video', src: [] }),

  youtube: (src?: string) => create<YouTube>({ type: 'youtube', src }),

  callout: (text = '') => create<Callout>({ type: 'callout', children: [Model.p(text)] }),
  calloutInline: (text = '') =>
    create<CalloutInline>({ type: 'callout_inline', children: [{ text }] }),

  conjugationTable: () =>
    Model.table([
      Model.tr([Model.th(''), Model.th('Singular'), Model.th('Plural')]),
      Model.tr([Model.th('1st Person'), Model.tc(''), Model.tc('')]),
      Model.tr([Model.th('2nd Person'), Model.tc(''), Model.tc('')]),
      Model.tr([Model.th('3rd Person'), Model.tc(''), Model.tc('')]),
    ]),

  conjugation: (title = '') =>
    create<Conjugation>({
      type: 'conjugation',
      verb: '',
      title,
      table: Model.conjugationTable(),
    }),

  dialogSpeaker: (name: string) => ({ name, image: '', id: guid() }),

  dialogLine: (speaker: string, text = '') =>
    create<DialogLine>({ type: 'dialog_line', speaker, children: [Model.p(text)] }),

  dialog: (title = '') =>
    create<Dialog>({
      type: 'dialog',
      title,
      lines: [],
      speakers: [Model.dialogSpeaker('Speaker #1'), Model.dialogSpeaker('Speaker #2')],
    }),

  figure: () => create<Figure>({ type: 'figure', title: [Model.p()], children: [Model.p()] }),

  foreign: (text = '') => create<Foreign>({ type: 'foreign', children: [{ text }] }),

  formula: (subtype: FormulaSubTypes = 'latex', src = '1 + 2 = 3') =>
    create<FormulaBlock>({ type: 'formula', src, subtype }),

  formulaInline: (subtype: FormulaSubTypes = 'latex', src = '1 + 2 = 3') =>
    create<FormulaInline>({ type: 'formula_inline', src, subtype }),

  webpage: (src?: string) => create<Webpage>({ type: 'iframe', src }),

  link: (href = '') => create<Hyperlink>({ type: 'a', href: normalizeHref(href), target: 'self' }),

  commandButton: () => create<CommandButton>({ type: 'command_button', style: 'button' }),

  page_link: (idref: number, purpose = 'none') =>
    create<PageLink>({ type: 'page_link', idref, purpose, children: [{ text: '' }] }),

  cite: (text = '', bibref: number) =>
    create<Citation>({ type: 'cite', bibref: bibref, children: [{ text }] }),

  image: (src?: string, altText?: string) =>
    create<ImageBlock>({ type: 'img', src, display: 'block', alt: altText }),

  imageInline: (src?: string) => create<ImageInline>({ type: 'img_inline', src }),

  audio: (src?: string) => create<Audio>({ type: 'audio', src }),

  p: (children?: Paragraph['children'] | string) => {
    if (!children) return create<Paragraph>({ type: 'p' });
    if (Array.isArray(children)) return create<Paragraph>({ type: 'p', children });
    return create<Paragraph>({ type: 'p', children: [{ text: children }] });
  },

  blockquote: () =>
    create<Blockquote>({
      type: 'blockquote',
    }),

  codeLine: (text: string) => create<CodeLine>({ type: 'code_line', children: [{ text }] }),

  code: (code = '') =>
    create<CodeV2>({
      type: 'code',
      code,
      language: 'Text',
    }),

  codeV1: (code = '') =>
    create<CodeV1>({
      type: 'code',
      language: 'Text',
      children: [Model.codeLine(code)],
    }),

  ecl: (code = '') =>
    create<ECLRepl>({
      type: 'ecl',
      code,
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
  definitionPronunciation: (overrides?: Partial<Pronunciation>) =>
    create<Pronunciation>({ type: 'pronunciation', children: [Model.p()], ...overrides }),
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

  trigger: (prompt = '') =>
    create<TriggerBlock>({ type: 'trigger', trigger_type: 'content', prompt: prompt }),
};
