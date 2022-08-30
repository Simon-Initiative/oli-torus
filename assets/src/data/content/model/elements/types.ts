import { RichText } from 'components/activities/types';
import { BaseElement, Descendant, Text } from 'slate';
import { Identifiable } from '../other';

interface SlateElement<Children extends Descendant[]> extends BaseElement, Identifiable {
  children: Children;
}

export type ModelElement = TopLevel | Block | Inline;

// A list of all our element types, including those that can't be "bare" inside a children array.
export type AllModelElements = ModelElement | SubElements;

// All allows all SlateElement types. Small disallows full-width items like tables, webpages. Inline is only formatted text and inline elements like links.
export type ContentModelMode = 'all' | 'small' | 'inline';

export type TopLevel =
  | TextBlock
  | List
  | MediaBlock
  | Table
  | Math
  | (CodeV1 | CodeV2)
  | Blockquote
  | FormulaBlock
  | Video
  | Semantic;

export type Block = TableRow | TableCell | ListItem | MathLine | CodeLine | FormulaBlock;

export type Semantic = Definition | Callout | Figure | Dialog;

export type Inline =
  | Hyperlink
  | Popup
  | InputRef
  | ImageInline
  | Citation
  | FormulaInline
  | CalloutInline;

export type TextBlock = Paragraph | Heading;
export type Heading =
  | HeadingOne
  | HeadingTwo
  | HeadingThree
  | HeadingFour
  | HeadingFive
  | HeadingSix;
export type List = OrderedList | UnorderedList;
export type MediaBlock = ImageBlock | YouTube | Audio | Webpage | Video;
export type SemanticChildren = TextBlock | Block;
// These types are only used inside other structured types and not directly as .children5
type SubElements = DefinitionMeaning | DefinitionPronunciation | DefinitionTranslation | DialogLine;

export type TableCell = TableHeader | TableData;

type HeadingChildren = Text[];
export interface Paragraph extends SlateElement<(InputRef | Text | ImageBlock)[]> {
  type: 'p';
}

export interface Figure extends SlateElement<SemanticChildren[]> {
  type: 'figure';
  title: string;
}

export interface Callout extends SlateElement<SemanticChildren[]> {
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

export const OrderedListStyles = [
  'none',
  'decimal',
  'decimal-leading-zero',
  'lower-roman',
  'upper-roman',
  'lower-alpha',
  'upper-alpha',
  'lower-latin',
  'upper-latin',
] as const;
export type OrderedListStyle = typeof OrderedListStyles[number];

export const UnorderdListStyles = ['none', 'disc', 'circle', 'square'];
export type UnorderedListStyle = typeof UnorderdListStyles[number];

type ListChildren = (ListItem | OrderedList | UnorderedList | Text)[];
export interface OrderedList extends SlateElement<ListChildren> {
  type: 'ol';
  style?: OrderedListStyle;
}

export interface UnorderedList extends SlateElement<ListChildren> {
  type: 'ul';
  style?: UnorderedListStyle;
}

type VoidChildren = Text[];

interface BaseImage extends SlateElement<VoidChildren> {
  src?: string;
  height?: number | string;
  width?: number | string;
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

export interface DefinitionPronunciation extends SlateElement<TextBlock[]> {
  src: string;
  contenttype: string;
  type: 'pronunciation';
}

export interface DefinitionTranslation extends SlateElement<TextBlock[]> {
  type: 'translation';
}

export interface DefinitionMeaning extends SlateElement<SemanticChildren[]> {
  type: 'meaning';
}

export interface Definition extends SlateElement<VoidChildren> {
  type: 'definition';
  term: string;
  meanings: DefinitionMeaning[];
  translations: DefinitionTranslation[];
  pronunciation: DefinitionPronunciation;
}

export interface DialogSpeaker {
  name: string;
  image: string;
  id: string;
}
export interface DialogLine {
  type: 'dialog_line';
  speaker: string;
  id: string;
  children: SemanticChildren[];
}
export interface Dialog extends SlateElement<VoidChildren> {
  type: 'dialog';
  title: string;
  speakers: DialogSpeaker[];
  lines: DialogLine[];
}

export type FormulaSubTypes = 'mathml' | 'latex';
interface Formula<typeIdentifier> extends SlateElement<VoidChildren> {
  type: typeIdentifier;
  subtype: FormulaSubTypes;
  src: string;
}

export type FormulaBlock = Formula<'formula'>;
export type FormulaInline = Formula<'formula_inline'>;
export interface VideoSource {
  url: string;
  contenttype: string;
}

export interface AudioSource {
  url: string;
  contenttype: string;
}
export interface Video extends SlateElement<VoidChildren> {
  type: 'video';
  poster?: string;
  src: VideoSource[];
  height?: number;
  width?: number;
}

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

export type TableRowStyle = 'alternating' | 'plain';
export type TableBorderStyle = 'solid' | 'hidden';
export interface Table extends SlateElement<TableRow[]> {
  type: 'table';
  caption?: Caption;
  border?: TableBorderStyle;
  rowstyle?: TableRowStyle;
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
  colspan?: number;
  rowspan?: number;
  align?: string;
}

export interface TableData extends SlateElement<TableCellChildren> {
  type: 'td';
  colspan?: number;
  rowspan?: number;
  align?: string;
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
