import { ModelElement } from 'data/content/model/elements/types';
import React from 'react';
import { Text } from 'slate';
import { WriterContext } from './context';

export type Next = () => React.ReactElement;
type ElementWriter = (ctx: WriterContext, next: Next, text: ModelElement) => React.ReactElement;

export interface WriterImpl {
  text: (ctx: WriterContext, text: Text) => React.ReactElement;
  p: ElementWriter;
  h1: ElementWriter;
  h2: ElementWriter;
  h3: ElementWriter;
  h4: ElementWriter;
  h5: ElementWriter;
  h6: ElementWriter;
  formula: ElementWriter;
  formulaInline: ElementWriter;
  callout: ElementWriter;
  calloutInline: ElementWriter;
  img: ElementWriter;
  img_inline: ElementWriter;
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
  cite: ElementWriter;
  inputRef: ElementWriter;
  popup: (
    ctx: WriterContext,
    anchorNext: Next,
    contentNext: Next,
    text: ModelElement,
  ) => React.ReactElement;
  unsupported: (ctx: WriterContext, element: ModelElement) => React.ReactElement;
}

export type ContentItem = { type: 'content'; children: ModelElement[] };
export function isContentItem(value: any): value is ContentItem {
  return value && value.type === 'content' && value.children !== undefined;
}

export type ContentTypes = ContentItem[] | ContentItem | ModelElement[] | ModelElement | Text;

export class ContentWriter {
  render(context: WriterContext, content: ContentItem[], impl: WriterImpl): React.ReactElement;
  render(context: WriterContext, content: ContentItem, impl: WriterImpl): React.ReactElement;
  render(context: WriterContext, content: ModelElement[], impl: WriterImpl): React.ReactElement;
  render(context: WriterContext, content: ModelElement, impl: WriterImpl): React.ReactElement;
  render(context: WriterContext, content: Text, impl: WriterImpl): React.ReactElement;
  render(context: WriterContext, content: ContentTypes, impl: WriterImpl): React.ReactElement {
    if (Array.isArray(content)) {
      return (
        <>
          {(content as Array<any>).map((item, i) => (
            <React.Fragment key={item.type + String(i)}>
              {this.render(context, item, impl)}
            </React.Fragment>
          ))}
        </>
      );
    }

    if (isContentItem(content)) {
      return (
        <>
          {(content.children as Array<any>).map((child) => (
            <React.Fragment key={child.id}>{this.render(context, child, impl)}</React.Fragment>
          ))}
        </>
      );
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
      case 'formula':
        return impl.formula(context, next, content);
      case 'formula_inline':
        return impl.formulaInline(context, next, content);
      case 'callout':
        return impl.callout(context, next, content);
      case 'callout_inline':
        return impl.calloutInline(context, next, content);
      case 'img':
        return impl.img(context, next, content);
      case 'img_inline':
        return impl.img_inline(context, next, content);
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
      case 'cite':
        return impl.cite(context, next, content);
      case 'input_ref':
        return impl.inputRef(context, next, content);
      case 'popup':
        return impl.popup(
          context,
          next,
          () => this.render(context, content.content, impl),
          content,
        );
      default:
        return impl.unsupported(context, content);
    }
  }
}
