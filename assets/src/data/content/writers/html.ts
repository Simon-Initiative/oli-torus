import { WriterImpl, Next } from './writer';
import { ModelElement, Image, HeadingSix, Paragraph, HeadingOne,
  HeadingTwo, HeadingThree, HeadingFour, HeadingFive, YouTube, Audio,
  Table, TableRow, TableHeader, TableData, OrderedList, UnorderedList,
  ListItem, Math, MathLine, Code, CodeLine, Blockquote, Hyperlink } from '../model';
import { Text } from 'slate';
import { WriterContext } from './context';

export class HtmlParser implements WriterImpl {
  private escapeXml = (text: string) => decodeURI(encodeURI(text));

  private wrapWithMarks(text: string, textEntity: Text): string {
    const supportedMarkTags: { [key: string]: string} = {
      em: 'em',
      strong: 'strong',
      mark: 'mark',
      del: 'del',
      var: 'var',
      code: 'code',
      sub: 'sub',
      sup: 'sup',
    };
    return Object.keys(textEntity)
      .filter(attr => textEntity[attr] === true)
      .map(attr => supportedMarkTags[attr])
      .filter(mark => mark)
      // .reverse()
      .reduce((acc, mark) => `<${mark}>${acc}</${mark}>`, text);
  }

  p = (context: WriterContext, next: Next, x: Paragraph) => `<p>${next()}</p>\n`;
  h1 = (context: WriterContext, next: Next, x: HeadingOne) => `<h1>${next()}</h1>\n`;
  h2 = (context: WriterContext, next: Next, x: HeadingTwo) => `<h2>${next()}</h2>\n`;
  h3 = (context: WriterContext, next: Next, x: HeadingThree) => `<h3>${next()}</h3>\n`;
  h4 = (context: WriterContext, next: Next, x: HeadingFour) => `<h4>${next()}</h4>\n`;
  h5 = (context: WriterContext, next: Next, x: HeadingFive) => `<h5>${next()}</h5>\n`;
  h6 = (context: WriterContext, next: Next, x: HeadingSix) => `<h6>${next()}</h6>\n`;
  img = (context: WriterContext, next: Next, attrs: Image) => {
    let heightWidth = '';
    if (attrs.height && attrs.width) {
      heightWidth = `height="${attrs.height}" width="${attrs.width}`;
    }
    return `<img ${heightWidth} style="display: block; max-height: 500px; margin-left: auto; margin-right: auto;" src="${attrs.src}"/>\n`;
  }

  youtube = (context: any, next: Next, { src }: YouTube) => `<iframe
  id="${src}"
  width="640"
  height="476"
  src="https://www.youtube.com/embed/${src}"
  frameBorder="0"
  style="display: block; margin-left: auto; margin-right: auto;"></iframe>`
  audio = (context: WriterContext, next: Next, { src }: Audio) => `<audio src="${src}"/>\n`;
  table = (context: WriterContext, next: Next, x: Table) => `<table>${next()}</table>\n`;
  tr = (context: WriterContext, next: Next, x: TableRow) => `<tr>${next()}</tr>\n`;
  th = (context: WriterContext, next: Next, x: TableHeader) => `<th>${next()}</th>\n`;
  td = (context: WriterContext, next: Next, x: TableData) => `<td>${next()}</td>\n`;
  ol = (context: WriterContext, next: Next, x: OrderedList) => `<ol>${next()}</ol>\n`;
  ul = (context: WriterContext, next: Next, x: UnorderedList) => `<ul>${next()}</ul>\n`;
  li = (context: WriterContext, next: Next, x: ListItem) => `<li>${next()}</li>\n`;
  math = (context: WriterContext, next: Next, x: Math) => `<div>${next()}</div>\n`;
  mathLine = (context: WriterContext, next: Next, x: MathLine) => `${next()}\n`;
  code = (context: WriterContext, next: Next,
    { language, startingLineNumberr, showNumbers }: Code) =>
    `<pre><code>${next()}</code></pre>\n`
  codeLine = (context: WriterContext, next: Next, x: CodeLine) => `${next()}\n`;
  blockquote = (context: WriterContext, next: Next, x: Blockquote) =>
    `<blockquote>${next()}</blockquote>\n`
  a = (context: WriterContext, next: Next,  { href } : Hyperlink) =>
    `<a href="${this.escapeXml(href)}">${next()}</a>\n`
  text = (context: WriterContext, textEntity: Text) =>
    this.wrapWithMarks(this.escapeXml(textEntity.text), textEntity)

  unsupported = (context: WriterContext, { type }: ModelElement) =>
    '<div class="content invalid">Content element is invalid</div>\n'
}
