import { WriterImpl, Next } from './writer';
import { ModelElement, Image, HeadingSix, Paragraph, HeadingOne,
  HeadingTwo, HeadingThree, HeadingFour, HeadingFive, YouTube, Audio,
  Table, TableRow, TableHeader, TableData, OrderedList, UnorderedList,
  ListItem, Math, MathLine, Code, CodeLine, Blockquote, Hyperlink } from '../model';
import { Text } from 'slate';
import { WriterContext } from './context';

// Important: any changes to this file must be replicated
// in content/html.ex for non-activity rendering.

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
      .reduce((acc, mark) => `<${mark}>${acc}</${mark}>`, text);
  }

  private figure(attrs: any, content: string) {
    if (!attrs.caption) {
      return content;
    }

    return (
      `<div class="figure-wrapper">
        <figure${attrs['full-width'] ? ' class="full-width"' : ''}>
          ${content}
          <figcaption${attrs['full-width'] ? ' class="full-width"' : ''}>${attrs.caption}</figcaption>
        </figure>
      </div>`
    );
  }

  p = (context: WriterContext, next: Next, x: Paragraph) => `<p>${next()}</p>\n`;
  h1 = (context: WriterContext, next: Next, x: HeadingOne) => `<h1>${next()}</h1>\n`;
  h2 = (context: WriterContext, next: Next, x: HeadingTwo) => `<h2>${next()}</h2>\n`;
  h3 = (context: WriterContext, next: Next, x: HeadingThree) => `<h3>${next()}</h3>\n`;
  h4 = (context: WriterContext, next: Next, x: HeadingFour) => `<h4>${next()}</h4>\n`;
  h5 = (context: WriterContext, next: Next, x: HeadingFive) => `<h5>${next()}</h5>\n`;
  h6 = (context: WriterContext, next: Next, x: HeadingSix) => `<h6>${next()}</h6>\n`;
  img = (context: WriterContext, next: Next, attrs: Image) =>
    this.figure(attrs, `<img class="block" src="${attrs.src}"/>\n`)

  youtube = (context: any, next: Next, attrs: YouTube) =>
    this.figure(
      Object.assign(attrs, { 'full-width': true }),
      `<div class="youtube-wrapper">
        <iframe id="${attrs.src}" allowfullscreen src="https://www.youtube.com/embed/${attrs.src}"></iframe>
      </div>`,
    )
  audio = (context: WriterContext, next: Next, attrs: Audio) =>
    this.figure(
      attrs,
      `<audio controls src="${attrs.src}">Your browser does not support the <code>audio</code> element.</audio>\n`,
    )
  table = (context: WriterContext, next: Next, attrs: Table) => {
    const caption = attrs.caption
      ? `<caption>${attrs.caption}</caption>`
      : '';

    return `<table>${caption}${next()}</table>\n`;
  }
  tr = (context: WriterContext, next: Next, x: TableRow) => `<tr>'${next()}</tr>\n`;
  th = (context: WriterContext, next: Next, x: TableHeader) => `<th>${next()}</th>\n`;
  td = (context: WriterContext, next: Next, x: TableData) => `<td>${next()}</td>\n`;
  ol = (context: WriterContext, next: Next, x: OrderedList) => `<ol>${next()}</ol>\n`;
  ul = (context: WriterContext, next: Next, x: UnorderedList) => `<ul>${next()}</ul>\n`;
  li = (context: WriterContext, next: Next, x: ListItem) => `<li>${next()}</li>\n`;
  math = (context: WriterContext, next: Next, x: Math) => `<div>${next()}</div>\n`;
  mathLine = (context: WriterContext, next: Next, x: MathLine) => `${next()}\n`;
  code = (context: WriterContext, next: Next, attrs: Code) =>
    this.figure(attrs, `<pre><code class="language-${attrs.language}">${next()}</code></pre>\n`)
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
