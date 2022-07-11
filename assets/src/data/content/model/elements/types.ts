import { RichText } from 'components/activities/types';
import { BaseElement, Descendant, Text } from 'slate';
import { Identifiable } from '../other';

interface SlateElement<Children extends Descendant[]> extends BaseElement, Identifiable {
  children: Children;
}

export type ModelElement = TopLevel | Block | Inline;

// All allows all SlateElement types. Small disallows full-width items like tables, webpages. Inline is only formatted text and inline elements like links.
export type ContentModelMode = 'all' | 'small' | 'inline';

type TopLevel =
  | TextBlock
  | List
  | MediaBlock
  | Table
  | Math
  | (CodeV1 | CodeV2)
  | Blockquote
  | FormulaBlock
  | Callout;

type Block = TableRow | TableCell | ListItem | MathLine | CodeLine | FormulaBlock | Callout;
type Inline = Hyperlink | Popup | InputRef | ImageInline | Citation | FormulaInline | CalloutInline;

type TextBlock = Paragraph | Heading;
type Heading = HeadingOne | HeadingTwo | HeadingThree | HeadingFour | HeadingFive | HeadingSix;
type List = OrderedList | UnorderedList;
type MediaBlock = ImageBlock | YouTube | Audio | Webpage;
type TableCell = TableHeader | TableData;

type HeadingChildren = Text[];
export interface Paragraph extends SlateElement<(InputRef | Text | ImageBlock)[]> {
  type: 'p';
}

export interface Callout extends SlateElement<Paragraph[]> {
  type: 'callout';
}

export interface CalloutInline extends SlateElement<(InputRef | Text | ImageInline)[]> {
  type: 'callout_inline';
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

interface BaseImage extends SlateElement<VoidChildren> {
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
}
export interface ImageBlock extends BaseImage {
  type: 'img';
  caption?: Caption;
  // Legacy, unused; was previously used to set image alignment (left, center, right)
  display?: string;
}

export interface ImageInline extends BaseImage {
  type: 'img_inline';
}

export type FormulaSubTypes = 'mathml' | 'latex';
interface Formula<typeIdentifier>
  extends SlateElement<(ImageInline | Hyperlink | Popup | InputRef)[]> {
  type: typeIdentifier;
  subtype: FormulaSubTypes;
  src: string;
}

export type FormulaBlock = Formula<'formula'>;
export type FormulaInline = Formula<'formula_inline'>;

export interface YouTube extends SlateElement<VoidChildren> {
  type: 'youtube';
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: Caption;
  // Legacy, unused;
  display?: string;
}

export interface Audio extends SlateElement<VoidChildren> {
  type: 'audio';
  src?: string;
  alt?: string;
  caption?: Caption;
}

// Webpage and Iframe are synonymous. Webpage is used in most UI-related
// code, and Iframe is used for the underlying slate data model.
export interface Webpage extends SlateElement<VoidChildren> {
  type: 'iframe';
  src?: string;
  height?: number;
  width?: number;
  alt?: string;
  caption?: Caption;
  // Legacy, unused
  display?: string;
}

export interface Table extends SlateElement<TableRow[]> {
  type: 'table';
  caption?: Caption;
}

export interface Math extends SlateElement<MathLine[]> {
  type: 'math';
}

export interface CodeV1 extends SlateElement<CodeLine[]> {
  type: 'code';
  language: string;
  caption?: Caption;
}

export interface CodeV2 extends SlateElement<VoidChildren> {
  type: 'code';
  code: string;
  language: string;
  caption?: Caption;
}

export type Code = CodeV2;

export interface Blockquote extends SlateElement<Paragraph[]> {
  type: 'blockquote';
}

export interface TableRow extends SlateElement<TableCell[]> {
  type: 'tr';
}

type TableCellChildren = (Paragraph | ImageBlock | YouTube | Audio | Math)[];
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

export interface Citation extends SlateElement<Text[]> {
  type: 'cite';
  bibref: number;
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
  trigger: any;
  content: RichText;
}

// Captions were formerly only strings
type CaptionV1 = string;
export type CaptionV2 = (Inline | Paragraph)[];
export type Caption = CaptionV2 | CaptionV1;
