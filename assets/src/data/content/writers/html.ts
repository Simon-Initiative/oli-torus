import { WriterImpl } from './writer';

export class HtmlParser implements WriterImpl {
  private escapeXml = (text: string) => decodeURI(encodeURI(text));

  private wrapWithMarks = (text: any, textEntity: any) => {
    const supportedMarkTags: any = {
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
      .reverse().reduce((acc, mark) => `<${mark}>${acc}</${mark}>`, text);
  };

  p = (context: any, next: any, x: any) => `<p>${next()}</p>\n`;
  h1 = (context: any, next: any, x: any) => `<h1>${next()}</h1>\n`;
  h2 = (context: any, next: any, x: any) => `<h2>${next()}</h2>\n`;
  h3 = (context: any, next: any, x: any) => `<h3>${next()}</h3>\n`;
  h4 = (context: any, next: any, x: any) => `<h4>${next()}</h4>\n`;
  h5 = (context: any, next: any, x: any) => `<h5>${next()}</h5>\n`;
  h6 = (context: any, next: any, x: any) => `<h6>${next()}</h6>\n`;
  img = (context: any, x: any, attrs: any) => {
    let heightWidth;
    if (attrs.height && attrs.width) {
      heightWidth = `height="${attrs.height}" width="${attrs.width}"`;
    }

    return`<img ${heightWidth}
      style="display: block; max-height: 500px; margin-left: auto; margin-right: auto;"
      src="${attrs.src}" />\n`;
  }

  youtube = (context: any, x: any, { src }: any) => `
    <iframe
      id='${src}'
      width='640'
      height='476'
      src='https://www.youtube.com/embed/${src}'
      frameBorder='0'
      style='display: block; margin-left: auto; margin-right: auto;'>
    </iframe>
  `
  audio = (context: any, x: any,  { src }: any) => `<audio src="${src}"/>\n`;
  table = (context: any, next: any, x: any) => `<table>${next()}</table>\n`;
  tr = (context: any, next: any, x: any) => `<tr>'${next()}</tr>\n`;
  th = (context: any, next: any, x: any) => `<th>${next()}</th>\n`;
  td = (context: any, next: any, x: any) => `<td>${next()}</td>\n`;
  ol = (context: any, next: any, x: any) => `<ol>${next()}</ol>\n`;
  ul = (context: any, next: any, x: any) => `<ul>${next()}</ul>\n`;
  li = (context: any, next: any, x: any) => `<li>${next()}</li>\n`;
  math = (context: any, next: any, x: any) => `<div>${next()}</div>\n`;
  mathLine = (context: any, next: any, x: any) => `${next()}\n`;
  code = (context: any, next: any, { language, startingLineNumberr, showNumbers }: any) =>
    `<pre><code>${next()}</pre></code>\n`
  codeLine = (context: any, next: any, x: any) => `${next()}\n`;
  blockquote = (context: any, next: any, x: any) => `<blockquote>${next()}</blockquote>\n`;
  a = (context: any, next: any,  { href } : any) => `<link href="${this.escapeXml(href)}">${next()}</link>\n`;
  definition = (context: any, next: any, x: any) => `<extra>${next()}</extra>\n`;
  text = (context: any, textEntity: any) =>
    this.wrapWithMarks(this.escapeXml(textEntity.text), textEntity)

  unsupported = (context: any, { type }: any) =>
    `<div class="unsupported-element">Element type "${type}" is not supported</div>\n`
}
