import { normalizeHref } from 'components/editing/elements/link/utils';
import {
  TableData,
  TableRow,
  ListItem,
  OrderedList,
  UnorderedList,
  Webpage,
  Hyperlink,
  Paragraph,
  Code,
  InputRef,
  Popup,
  Table,
  YouTube,
  Image,
  Audio,
  Blockquote,
  ModelElement,
  HeadingOne,
  HeadingTwo,
} from 'data/content/model/elements/types';
import { Text } from 'slate';
import guid from 'utils/guid';

function create<E extends ModelElement>(params: Partial<E>): E {
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

  youtube: (src?: string) => create<YouTube>({ type: 'youtube', src }),

  webpage: (src?: string) => create<Webpage>({ type: 'iframe', src }),

  link: (href = '') => create<Hyperlink>({ type: 'a', href: normalizeHref(href), target: 'self' }),

  image: (src?: string) => create<Image>({ type: 'img', src, display: 'block' }),

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

  code: (children = '') =>
    create<Code>({
      type: 'code',
      code: children,
      language: 'Text',
    }),

  inputRef: () => create<InputRef>({ type: 'input_ref' }),

  popup: () =>
    create<Popup>({
      type: 'popup',
      trigger: 'hover',
      content: [Model.p()],
    }),
};
