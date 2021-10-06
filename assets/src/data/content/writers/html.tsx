/* eslint-disable react/display-name */
import { DropdownInput } from 'components/activities/common/delivery/inputs/DropdownInput';
import { HintsBadge } from 'components/activities/common/delivery/inputs/HintsBadge';
import { NumericInput } from 'components/activities/common/delivery/inputs/NumericInput';
import { TextInput } from 'components/activities/common/delivery/inputs/TextInput';
import {
  Audio,
  Blockquote,
  Code,
  CodeLine,
  HeadingFive,
  HeadingFour,
  HeadingOne,
  HeadingSix,
  HeadingThree,
  HeadingTwo,
  Hyperlink,
  Image,
  InputRef,
  ListItem,
  Math,
  MathLine,
  ModelElement,
  OrderedList,
  Paragraph,
  Table,
  TableData,
  TableHeader,
  TableRow,
  UnorderedList,
  Webpage,
  YouTube,
} from 'data/content/model';
import React from 'react';
import { Text } from 'slate';
import { assertNever, valueOr } from 'utils/common';
import { WriterContext } from './context';
import { Next, WriterImpl } from './writer';

// Important: any changes to this file must be replicated
// in content/html.ex for non-activity rendering.

function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export class HtmlParser implements WriterImpl {
  private escapeXml = (text: string) => decodeURI(encodeURI(text));

  private wrapWithMarks(text: string, textEntity: Text): React.ReactElement {
    const supportedMarkTags: { [key: string]: (e: React.ReactElement) => React.ReactElement } = {
      em: (e) => <em>{e}</em>,
      strong: (e) => <strong>{e}</strong>,
      mark: (e) => <mark>{e}</mark>,
      del: (e) => <del>{e}</del>,
      var: (e) => <var>{e}</var>,
      code: (e) => <code>{e}</code>,
      sub: (e) => <sub>{e}</sub>,
      sup: (e) => <sup>{e}</sup>,
    };
    return Object.keys(textEntity)
      .filter((attr) => textEntity[attr] === true)
      .map((attr) => supportedMarkTags[attr])
      .filter((mark) => mark)
      .reduce((acc, mark) => mark(acc), <>{text}</>);
  }

  private figure(attrs: any, content: React.ReactElement) {
    if (!attrs.caption) {
      return content;
    }

    return (
      <div className="figure-wrapper">
        <figure className="figure embed-responsive text-center">
          {content}
          <figcaption className="figure-caption text-center">
            {this.escapeXml(attrs.caption)}
          </figcaption>
        </figure>
      </div>
    );
  }
  p(context: WriterContext, next: Next, _x: Paragraph) {
    return <p>{next()}</p>;
  }
  h1(context: WriterContext, next: Next, _x: HeadingOne) {
    return <h1>{next()}</h1>;
  }
  h2(context: WriterContext, next: Next, _x: HeadingTwo) {
    return <h2>{next()}</h2>;
  }
  h3(context: WriterContext, next: Next, _x: HeadingThree) {
    return <h3>{next()}</h3>;
  }
  h4(context: WriterContext, next: Next, _x: HeadingFour) {
    return <h4>{next()}</h4>;
  }
  h5(context: WriterContext, next: Next, _x: HeadingFive) {
    return <h5>{next()}</h5>;
  }
  h6(context: WriterContext, next: Next, _x: HeadingSix) {
    return <h6>{next()}</h6>;
  }
  img(context: WriterContext, next: Next, attrs: Image) {
    return this.figure(
      attrs,
      <img
        className="figure-img img-fluid"
        alt={attrs.alt ? this.escapeXml(attrs.alt) : ''}
        width={attrs.width ? this.escapeXml(String(attrs.width)) : undefined}
        height={attrs.height ? this.escapeXml(String(attrs.height)) : undefined}
        src={this.escapeXml(attrs.src)}
      />,
    );
  }
  youtube(context: WriterContext, next: Next, attrs: YouTube) {
    return this.iframe(context, next, {
      ...attrs,
      src: `https://www.youtube.com/embed/${this.escapeXml(attrs.src)}`,
    });
  }
  iframe(context: WriterContext, next: Next, attrs: Webpage | YouTube) {
    return this.figure(
      attrs,
      <div className="embed-responsive embed-responsive-16by9">
        <iframe className="embed-responsive-item" allowFullScreen src={this.escapeXml(attrs.src)} />
      </div>,
    );
  }
  audio(context: WriterContext, next: Next, attrs: Audio) {
    return this.figure(
      attrs,
      <audio controls src={this.escapeXml(attrs.src)}>
        Your browser does not support the <code>audio</code> element.
      </audio>,
    );
  }
  table(context: WriterContext, next: Next, attrs: Table) {
    return (
      <table>
        {attrs.caption ? <caption>{this.escapeXml(attrs.caption)}</caption> : undefined}
        {next()}
      </table>
    );
  }
  tr(context: WriterContext, next: Next, _x: TableRow) {
    return <tr>{next()}</tr>;
  }
  th(context: WriterContext, next: Next, _x: TableHeader) {
    return <th>{next()}</th>;
  }
  td(context: WriterContext, next: Next, _x: TableData) {
    return <td>{next()}</td>;
  }
  ol(context: WriterContext, next: Next, _x: OrderedList) {
    return <ol>{next()}</ol>;
  }
  ul(context: WriterContext, next: Next, _x: UnorderedList) {
    return <ul>{next()}</ul>;
  }
  li(context: WriterContext, next: Next, _x: ListItem) {
    return <li>{next()}</li>;
  }
  math(context: WriterContext, next: Next, _x: Math) {
    return <div>{next()}</div>;
  }
  mathLine(context: WriterContext, next: Next, _x: MathLine) {
    return next();
  }
  code(context: WriterContext, next: Next, attrs: Code) {
    return this.figure(
      attrs,
      <pre>
        <code className={`language-${this.escapeXml(attrs.language)}`}>{next()}</code>
      </pre>,
    );
  }
  codeLine(context: WriterContext, next: Next, _x: CodeLine) {
    return next();
  }
  blockquote(context: WriterContext, next: Next, _x: Blockquote) {
    return <blockquote>{next()}</blockquote>;
  }
  a(context: WriterContext, next: Next, { href }: Hyperlink) {
    if (href.startsWith('/course/link/')) {
      let internalHref = href;
      if (context.sectionSlug) {
        const revisionSlug = href.replace(/^\/course\/link\//, '');
        internalHref = `/sections/${context.sectionSlug}/page/${revisionSlug}`;
      } else {
        internalHref = '#';
      }

      return (
        <a className="internal-link" href={this.escapeXml(internalHref)}>
          {next()}
        </a>
      );
    }

    return (
      <a className="external-link" href={this.escapeXml(href)} target="_blank" rel="noreferrer">
        {next()}
      </a>
    );
  }
  inputRef(context: WriterContext, _next: Next, inputRef: InputRef) {
    const { inputRefContext } = context;
    const inputData = inputRefContext?.inputs.get(inputRef.id);
    if (!inputRefContext || !inputData) {
      return <TextInput onChange={() => {}} value="" disabled />;
    }

    const shared = {
      onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
        inputRefContext.onChange(inputRef.id, e),
      value: valueOr(inputData.value, ''),
      disabled: inputRefContext.disabled,
      placeholder: inputData.placeholder || '',
    };

    const withHints = (element: React.ReactElement) => (
      <>
        {element}
        <HintsBadge
          hasHints={inputData.hasHints}
          toggleHints={() => inputRefContext.toggleHints(inputData.input.id)}
        />
      </>
    );

    switch (inputData.input.inputType) {
      case 'numeric':
        return withHints(<NumericInput {...shared} />);
      case 'text':
        return withHints(<TextInput {...shared} />);
      case 'dropdown':
        return withHints(<DropdownInput {...shared} options={inputData.input.options} />);
      default:
        assertNever(inputData.input);
    }
  }
  text(context: WriterContext, textEntity: Text) {
    return this.wrapWithMarks(escapeHtml(textEntity.text), textEntity);
  }
  unsupported(_context: WriterContext, x: ModelElement) {
    console.error('Content element ' + JSON.stringify(x) + ' is invalid and could not display.');
    return <div className="content invalid">Content element is invalid</div>;
  }
}
