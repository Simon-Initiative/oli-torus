import { Element } from 'slate';

export function create<ModelElement>(params: ModelElement): ModelElement {
    return (params as ModelElement);
}

export function mutate<ModelElement>(obj: ModelElement, changes: Object): ModelElement {
    return Object.assign({}, obj, changes) as ModelElement;
}

export type ModelElement
    = Paragraph | HeadingOne | HeadingTwo | HeadingThree | HeadingFour | HeadingFive | HeadingSix | Image | YouTube
    | Audio | Table | TableHead | TableBody | TableFooter | TableRow | TableHeader | TableData | OrderedList | UnorderedList
    | ListItem | Math | MathLine | Code | CodeLine | Blockquote | Example | Hyperlink | Definition | Citation;

export interface Identifiable {
    id: string;
}

export interface Paragraph extends Element, Identifiable {
    type: 'p';
}

export interface HeadingOne extends Element, Identifiable {
    type: 'h1';
}

export interface HeadingTwo extends Element, Identifiable {
    type: 'h2';
}

export interface HeadingThree extends Element, Identifiable {
    type: 'h3';
}

export interface HeadingFour extends Element, Identifiable {
    type: 'h4';
}

export interface HeadingFive extends Element, Identifiable {
    type: 'h5';
}

export interface HeadingSix extends Element, Identifiable {
    type: 'h6';
}

export interface Image extends Element, Identifiable {
    type: 'img';
    src: string;
    height: string;
    width: string;
    alt?: string;
}

export interface YouTube extends Element, Identifiable {
    type: 'youtube';
    src: string;
    height: string;
    width: string;
    alt: string;
}

export interface Audio extends Element, Identifiable {
    type: 'audio';
    src: string;
    alt: string;
}

export interface Table extends Element, Identifiable {
    type: 'table';
}

export interface TableHead extends Element, Identifiable {
    type: 'thead';
}
export interface TableBody extends Element, Identifiable {
    type: 'tbody';
}

export interface TableFooter extends Element, Identifiable {
    type: 'tfoot';
}

export interface TableRow extends Element, Identifiable {
    type: 'tr';
}

export interface TableHeader extends Element, Identifiable {
    type: 'th';
}

export interface TableData extends Element, Identifiable {
    type: 'td';
}

export interface OrderedList extends Element, Identifiable {
    type: 'ol';
}

export interface UnorderedList extends Element, Identifiable {
    type: 'ul';
}

export interface ListItem extends Element, Identifiable {
    type: 'li';
}

export interface Math extends Element, Identifiable {
    type: 'math';
}

export interface MathLine extends Element, Identifiable {
    type: 'math_line';
}

export interface Code extends Element, Identifiable {
    type: 'code';
    language: string;
    startingLineNumber: number;
}

export interface CodeLine extends Element, Identifiable {
    type: 'code_line';
}

export interface Blockquote extends Element, Identifiable {
    type: 'blockquote';
}

export interface Example extends Element, Identifiable {
    type: 'example';
}

// Inlines

export interface Hyperlink extends Element, Identifiable {
    type: 'a';
    href: string;
    target: string;
}

export interface Definition extends Element, Identifiable {
    type: 'dfn';
    definition: string;
}

export interface Citation extends Element, Identifiable {
    type: 'cite';
    ordinal: number;
}

export type Mark = 'em' | 'strong' | 'mark' | 'del' | 'var' | 'code' | 'sub' | 'sup';

export const schema = {
    p: { isVoid: false, isBlock: true },
    h1: { isVoid: false, isBlock: true },
    h2: { isVoid: false, isBlock: true },
    h3: { isVoid: false, isBlock: true },
    h4: { isVoid: false, isBlock: true },
    h5: { isVoid: false, isBlock: true },
    h6: { isVoid: false, isBlock: true },
    img: { isVoid: true, isBlock: true },
    youtube: { isVoid: true, isBlock: true },
    audio: { isVoid: true, isBlock: true },
    table: { isVoid: false, isBlock: true },
    thead: { isVoid: false, isBlock: true },
    tbody: { isVoid: false, isBlock: true },
    tfoot: { isVoid: false, isBlock: true },
    tr: { isVoid: false, isBlock: true },
    th: { isVoid: false, isBlock: true },
    td: { isVoid: false, isBlock: true },
    ol: { isVoid: false, isBlock: true },
    ul: { isVoid: false, isBlock: true },
    li: { isVoid: false, isBlock: true },
    math: { isVoid: false, isBlock: true },
    math_line: { isVoid: false, isBlock: true },
    code: { isVoid: false, isBlock: true },
    code_line: { isVoid: false, isBlock: true },
    blockquote: { isVoid: false, isBlock: true },
    example: { isVoid: false, isBlock: true },
    a: { isVoid: false, isBlock: false },
    dfn: { isVoid: false, isBlock: false },
    cite: { isVoid: false, isBlock: false },
};


