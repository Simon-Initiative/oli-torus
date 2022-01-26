import { RichText } from 'components/activities/types';
import { OverlayTriggerType } from 'react-bootstrap/esm/OverlayTrigger';
import { BaseElement, Descendant, Text } from 'slate';
import { Identifiable } from '../other';

interface SlateElement<Children extends Descendant[]> extends BaseElement, Identifiable {
  children: Children;
}

export type ModelElement = TopLevel | Block | Inline;

type TopLevel = TextBlock | List | Media | Table | Math | (CodeV1 | CodeV2) | Blockquote;
type Block = TableRow | TableCell | ListItem | MathLine | CodeLine;
type Inline = Hyperlink | Popup | InputRef;

type TextBlock = Paragraph | Heading;
type Heading = HeadingOne | HeadingTwo | HeadingThree | HeadingFour | HeadingFive | HeadingSix;
type List = OrderedList | UnorderedList;
type Media = Image | YouTube | Audio | Webpage;
type TableCell = TableHeader | TableData;

type HeadingChildren = Text[];
export interface Paragraph extends SlateElement<(InputRef | Text)[]> {
  type: 'p';
}

export interface HeadingOne extends SlateElement<HeadingChildren> {
  type: 'h1';
}

export interface HeadingTwo extends SlateElement<HeadingChildren> {
  type: 'h2';
}

export interface HeadingThree extends SlateElement<HeadingChildren> {
  type: 'h3';
}

export interface HeadingFour extends SlateElement<HeadingChildren> {
  type: 'h4';
}

export interface HeadingFive extends SlateElement<HeadingChildren> {
  type: 'h5';
}

export interface HeadingSix extends SlateElement<HeadingChildren> {
  type: 'h6';
}

type ListChildren = (ListItem | OrderedList | UnorderedList | Text)[];
export interface OrderedList extends SlateElement<ListChildren> {
  type: 'ol';
}

export interface UnorderedList extends SlateElement<ListChildren> {
  type: 'ul';
}

type VoidChildren = Text[];
export interface Image extends SlateElement<VoidChildren> {
  type: 'img';
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  // Legacy, unused;
  display?: string;
}

export interface YouTube extends SlateElement<VoidChildren> {
  type: 'youtube';
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  // Legacy, unused;
  display?: string;
}

export interface Audio extends SlateElement<VoidChildren> {
  type: 'audio';
  src?: string;
  alt?: string;
  caption?: string;
}

// Webpage and Iframe are synonymous. Webpage is used in most UI-related
// code, and Iframe is used for the underlying slate data model.
export interface Webpage extends SlateElement<VoidChildren> {
  type: 'iframe';
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: string;
  // Legacy, unused
  display?: string;
}

export interface Table extends SlateElement<TableRow[]> {
  type: 'table';
  caption?: string;
}

export interface Math extends SlateElement<MathLine[]> {
  type: 'math';
}

export interface CodeV1 extends SlateElement<CodeLine[]> {
  type: 'code';
  language: string;
  caption?: string;
}
export interface CodeV2 extends SlateElement<VoidChildren> {
  type: 'code';
  code: string;
  language: string;
  caption?: string;
}
export type Code = CodeV2;

export interface Blockquote extends SlateElement<Paragraph[]> {
  type: 'blockquote';
}

export interface TableRow extends SlateElement<TableCell[]> {
  type: 'tr';
}

type TableCellChildren = (Paragraph | Image | YouTube | Audio | Math)[];
export interface TableHeader extends SlateElement<TableCellChildren> {
  type: 'th';
}

export interface TableData extends SlateElement<TableCellChildren> {
  type: 'td';
}

export interface ListItem extends SlateElement<(List | Text)[]> {
  type: 'li';
}

export interface MathLine extends SlateElement<Text[]> {
  type: 'math_line';
}

export interface CodeLine extends SlateElement<Text[]> {
  type: 'code_line';
}

export interface Hyperlink extends SlateElement<Text[]> {
  type: 'a';
  href: string;
  target: string;
}

export interface InputRef extends SlateElement<Text[]> {
  type: 'input_ref';
}

export interface Popup extends SlateElement<Text[]> {
  type: 'popup';
  trigger: OverlayTriggerType;
  content: RichText;
}
