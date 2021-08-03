import { WriterContext } from './context';
import { ModelElement } from '../model';
import { Text } from 'slate';

export type Next = () => string;
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
  iframe: ElementWriter;
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
  unsupported: (ctx: WriterContext, element: ModelElement) => string;
}

type ContentItem = { type: 'content'; children: ModelElement[] };
function isContentItem(value: any): value is ContentItem {
  return value && value.type === 'content' && value.children !== undefined;
}

type ContentTypes = ContentItem[] | ContentItem | ModelElement[] | ModelElement | Text;

export class ContentWriter {
  render(context: WriterContext, content: ContentItem[], impl: WriterImpl): string;
  render(context: WriterContext, content: ContentItem, impl: WriterImpl): string;
  render(context: WriterContext, content: ModelElement[], impl: WriterImpl): string;
  render(context: WriterContext, content: ModelElement, impl: WriterImpl): string;
  render(context: WriterContext, content: Text, impl: WriterImpl): string;
  render(context: WriterContext, content: ContentTypes, impl: WriterImpl): string {
    if (Array.isArray(content)) {
      // Typescript seems not to be able to recognize the overloaded function signatures here
      return (content as any).map((item: any) => this.render(context, item, impl)).join('');
    }

    if (isContentItem(content)) {
      return content.children.map((child) => this.render(context, child, impl)).join('');
    }

    if (Text.isText(content)) {
      return impl.text(context, content);
    }

    const next = () => this.render(context, content.children as ModelElement[], impl);

    switch (content.type) {
      case 'p':
        return impl.p(context, next, content);
      case 'h1':
        return impl.h1(context, next, content);
      case 'h2':
        return impl.h2(context, next, content);
      case 'h3':
        return impl.h3(context, next, content);
      case 'h4':
        return impl.h4(context, next, content);
      case 'h5':
        return impl.h5(context, next, content);
      case 'h6':
        return impl.h6(context, next, content);
      case 'img':
        return impl.img(context, next, content);
      case 'youtube':
        return impl.youtube(context, next, content);
      case 'iframe':
        return impl.iframe(context, next, content);
      case 'audio':
        return impl.audio(context, next, content);
      case 'table':
        return impl.table(context, next, content);
      case 'tr':
        return impl.tr(context, next, content);
      case 'th':
        return impl.th(context, next, content);
      case 'td':
        return impl.td(context, next, content);
      case 'ol':
        return impl.ol(context, next, content);
      case 'ul':
        return impl.ul(context, next, content);
      case 'li':
        return impl.li(context, next, content);
      case 'math':
        return impl.math(context, next, content);
      case 'math_line':
        return impl.mathLine(context, next, content);
      case 'code':
        return impl.code(context, next, content);
      case 'code_line':
        return impl.codeLine(context, next, content);
      case 'blockquote':
        return impl.blockquote(context, next, content);
      case 'a':
        return impl.a(context, next, content);
      default:
        return impl.unsupported(context, content);
    }
  }
}
