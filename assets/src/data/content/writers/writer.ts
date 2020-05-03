import { WriterContext } from './context';
import { ModelElement } from '../model';
import { Text } from 'slate';
import { RichText } from 'components/activities/multiple_choice/schema';

type Next = () => string;
type ElementWriter = (ctx: WriterContext, next: Next, text: ModelElement) => string;

export interface WriterImpl {
  text: (ctx: WriterContext, text: Text) => string;
  p: ElementWriter;
  h1: ElementWriter;
  h2: ElementWriter;
  h3: ElementWriter;
  h4: ElementWriter;
  h5: ElementWriter;
  h6: ElementWriter;
  img: ElementWriter;
  youtube: ElementWriter;
  audio: ElementWriter;
  table: ElementWriter;
  tr: ElementWriter;
  th: ElementWriter;
  td: ElementWriter;
  ol: ElementWriter;
  ul: ElementWriter;
  li: ElementWriter;
  math: ElementWriter;
  mathLine: ElementWriter;
  code: ElementWriter;
  codeLine: ElementWriter;
  blockquote: ElementWriter;
  a: ElementWriter;
  definition: ElementWriter;
}

export class ContentWriter {

  render(context: WriterContext, content: { content: any }[], impl: WriterImpl): string;
  render(context: WriterContext, content: RichText, impl: WriterImpl): string;
  render(context: WriterContext, content: ModelElement, impl: WriterImpl): string;
  render(context: WriterContext, content: Text, impl: WriterImpl): string;

  render(context: any, content: any, impl: any): any {
    if (Array.isArray(content)) {
      return content.map(item => this.render(context, item, impl)).join('');
    }

    // top-level items are of type 'content'
    if (content.type === 'content' && content.children !== undefined) {
      return content.children.map((child: any) => this.render(context, child, impl)).join('');
    }

    // content lists consists of items of type 1) { text } or 2) { type }
    // 1) { text } items
    if (content.text !== undefined) {
      return impl.text(context, content);
    }

    // 2) { type } items
    const next = () => this.render(context, content.children, impl);

    switch (content.type) {
      case 'p': return impl.p(context, next, content);
      case 'h1': return  impl.h1(context, next, content);
      case 'h2': return impl.h2(context, next, content);
      case 'h3': return impl.h3(context, next, content);
      case 'h4': return impl.h4(context, next, content);
      case 'h5': return impl.h5(context, next, content);
      case 'h6': return impl.h6(context, next, content);
      case 'img': return impl.img(context, next, content);
      case 'youtube': return impl.youtube(context, next, content);
      case 'audio': return impl.audio(context, next, content);
      case 'table': return impl.table(context, next, content);
      case 'tr': return impl.tr(context, next, content);
      case 'th': return impl.th(context, next, content);
      case 'td': return impl.td(context, next, content);
      case 'ol': return impl.ol(context, next, content);
      case 'ul': return impl.ul(context, next, content);
      case 'li': return impl.li(context, next, content);
      case 'math': return impl.math(context, next, content);
      case 'math_line': return impl.mathLine(context, next, content);
      case 'code': return impl.code(context, next, content);
      case 'code_line': return impl.codeLine(context, next, content);
      case 'blockquote': return impl.blockquote(context, next, content);
      case 'a': return impl.a(context, next, content);
      default: return impl.unsupported(context, content);
    }
  }
}

