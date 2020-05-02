export const impl = () => {
  const escapeXml = (text: string) => decodeURI(encodeURI(text));

  const wrapWithMarks = (text: any, textEntity: any) => {
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

  const p = (context: any, next: any, x: any) => `<p>${next()}</p>\n`;
  const h1 = (context: any, next: any, x: any) => `<h1>${next()}</h1>\n`;
  const h2 = (context: any, next: any, x: any) => `<h2>${next()}</h2>\n`;
  const h3 = (context: any, next: any, x: any) => `<h3>${next()}</h3>\n`;
  const h4 = (context: any, next: any, x: any) => `<h4>${next()}</h4>\n`;
  const h5 = (context: any, next: any, x: any) => `<h5>${next()}</h5>\n`;
  const h6 = (context: any, next: any, x: any) => `<h6>${next()}</h6>\n`;
  const img = (context: any, x: any, attrs: any) => {
    let heightWidth;
    if (attrs.height && attrs.width) {
      heightWidth = `height="${attrs.height}" width="${attrs.width}"`;
    }

    return`<img ${heightWidth}
      style="display: block; max-height: 500px; margin-left: auto; margin-right: auto;"
      src="${attrs.src}" />\n`;
  };

  const youtube = (context: any, x: any, { src }: any) => `
    <iframe
      id='${src}'
      width='640'
      height='476'
      src='https://www.youtube.com/embed/${src}'
      frameBorder='0'
      style='display: block; margin-left: auto; margin-right: auto;'>
    </iframe>`;

  const audio = (context: any, x: any,  { src }: any) => `<audio src="${src}"/>\n`;
  const table = (context: any, next: any, x: any) => `<table>${next()}</table>\n`;
  const tr = (context: any, next: any, x: any) => `<tr>'${next()}</tr>\n`;
  const th = (context: any, next: any, x: any) => `<th>${next()}</th>\n`;
  const td = (context: any, next: any, x: any) => `<td>${next()}</td>\n`;
  const ol = (context: any, next: any, x: any) => `<ol>${next()}</ol>\n`;
  const ul = (context: any, next: any, x: any) => `<ul>${next()}</ul>\n`;
  const li = (context: any, next: any, x: any) => `<li>${next()}</li>\n`;
  const math = (context: any, next: any, x: any) => `<div>${next()}</div>\n`;
  const mathLine = (context: any, next: any, x: any) => `${next()}\n`;
  const code = (context: any, next: any, { language, startingLineNumberr, showNumbers }: any) =>
    `<pre><code>${next()}</pre></code>\n`;
  const codeLine = (context: any, next: any, x: any) => `${next()}\n`;
  const blockquote = (context: any, next: any, x: any) => `<blockquote>${next()}</blockquote>\n`;
  const a = (context: any, next: any,  { href } : any) => `<link href="${escapeXml(href)}">${next()}</link>\n`;
  const definition = (context: any, next: any, x: any) => `<extra>${next()}</extra>\n`;
  const text = (context: any, textEntity: any) =>
    wrapWithMarks(escapeXml(textEntity.text), textEntity);

  const unsupported = (context: any,  { type }: any) =>
    `<div class="unsupported-element">Element type "${type}" is not supported</div>\n`;

  return {
    p,
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    img,
    youtube,
    audio,
    table,
    tr,
    th,
    td,
    ol,
    ul,
    li,
    math,
    mathLine,
    code,
    codeLine,
    blockquote,
    a,
    definition,
    text,
    unsupported,
  };
};
