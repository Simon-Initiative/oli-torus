/* eslint-disable react/display-name */
import { DropdownInput } from 'components/activities/common/delivery/inputs/DropdownInput';
import { HintsBadge } from 'components/activities/common/delivery/inputs/HintsBadge';
import { NumericInput } from 'components/activities/common/delivery/inputs/NumericInput';
import { TextInput } from 'components/activities/common/delivery/inputs/TextInput';
import React from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { assertNever, valueOr } from 'utils/common';
// Important: any changes to this file must be replicated
// in content/html.ex for non-activity rendering.
export class HtmlParser {
    constructor() {
        this.escapeXml = (text) => decodeURI(encodeURI(text));
    }
    wrapWithMarks(text, textEntity) {
        const supportedMarkTags = {
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
    figure(attrs, content) {
        if (!attrs.caption) {
            return content;
        }
        return (<div className="figure-wrapper">
        <figure className="figure embed-responsive text-center">
          {content}
          <figcaption className="figure-caption text-center">
            {this.escapeXml(attrs.caption)}
          </figcaption>
        </figure>
      </div>);
    }
    p(context, next, _x) {
        return <p>{next()}</p>;
    }
    h1(context, next, _x) {
        return <h1>{next()}</h1>;
    }
    h2(context, next, _x) {
        return <h2>{next()}</h2>;
    }
    h3(context, next, _x) {
        return <h3>{next()}</h3>;
    }
    h4(context, next, _x) {
        return <h4>{next()}</h4>;
    }
    h5(context, next, _x) {
        return <h5>{next()}</h5>;
    }
    h6(context, next, _x) {
        return <h6>{next()}</h6>;
    }
    img(context, next, attrs) {
        return this.figure(attrs, <img className="figure-img img-fluid" alt={attrs.alt ? this.escapeXml(attrs.alt) : ''} width={attrs.width ? this.escapeXml(String(attrs.width)) : undefined} height={attrs.height ? this.escapeXml(String(attrs.height)) : undefined} src={this.escapeXml(attrs.src)}/>);
    }
    youtube(context, next, attrs) {
        return this.iframe(context, next, Object.assign(Object.assign({}, attrs), { src: `https://www.youtube.com/embed/${this.escapeXml(attrs.src)}` }));
    }
    iframe(context, next, attrs) {
        return this.figure(attrs, <div className="embed-responsive embed-responsive-16by9">
        <iframe className="embed-responsive-item" allowFullScreen src={this.escapeXml(attrs.src)}/>
      </div>);
    }
    audio(context, next, attrs) {
        return this.figure(attrs, <audio controls src={this.escapeXml(attrs.src)}>
        Your browser does not support the <code>audio</code> element.
      </audio>);
    }
    table(context, next, attrs) {
        return (<table>
        {attrs.caption ? <caption>{this.escapeXml(attrs.caption)}</caption> : undefined}
        {next()}
      </table>);
    }
    tr(context, next, _x) {
        return <tr>{next()}</tr>;
    }
    th(context, next, _x) {
        return <th>{next()}</th>;
    }
    td(context, next, _x) {
        return <td>{next()}</td>;
    }
    ol(context, next, _x) {
        return <ol>{next()}</ol>;
    }
    ul(context, next, _x) {
        return <ul>{next()}</ul>;
    }
    li(context, next, _x) {
        return <li>{next()}</li>;
    }
    math(context, next, _x) {
        return <div>{next()}</div>;
    }
    mathLine(context, next, _x) {
        return next();
    }
    code(context, next, attrs) {
        return this.figure(attrs, <pre>
        <code className={`language-${this.escapeXml(attrs.language)}`}>{next()}</code>
      </pre>);
    }
    codeLine(context, next, _x) {
        return next();
    }
    blockquote(context, next, _x) {
        return <blockquote>{next()}</blockquote>;
    }
    a(context, next, { href }) {
        if (href.startsWith('/course/link/')) {
            let internalHref = href;
            if (context.sectionSlug) {
                const revisionSlug = href.replace(/^\/course\/link\//, '');
                internalHref = `/sections/${context.sectionSlug}/page/${revisionSlug}`;
            }
            else {
                internalHref = '#';
            }
            return (<a className="internal-link" href={this.escapeXml(internalHref)}>
          {next()}
        </a>);
        }
        return (<a className="external-link" href={this.escapeXml(href)} target="_blank" rel="noreferrer">
        {next()}
      </a>);
    }
    inputRef(context, _next, inputRef) {
        const { inputRefContext } = context;
        const inputData = inputRefContext === null || inputRefContext === void 0 ? void 0 : inputRefContext.inputs.get(inputRef.id);
        if (!inputRefContext || !inputData) {
            return <TextInput onChange={() => { }} value="" disabled/>;
        }
        const shared = {
            onChange: (e) => inputRefContext.onChange(inputRef.id, e),
            value: valueOr(inputData.value, ''),
            disabled: inputRefContext.disabled,
            placeholder: inputData.placeholder || '',
        };
        const withHints = (element) => (<>
        {element}
        <HintsBadge hasHints={inputData.hasHints} toggleHints={() => inputRefContext.toggleHints(inputData.input.id)}/>
      </>);
        switch (inputData.input.inputType) {
            case 'numeric':
                return withHints(<NumericInput {...shared}/>);
            case 'text':
                return withHints(<TextInput {...shared}/>);
            case 'dropdown':
                return withHints(<DropdownInput {...shared} options={inputData.input.options} selected={inputData.value}/>);
            default:
                assertNever(inputData.input);
        }
    }
    popup(context, anchorNext, contentNext, popup) {
        const trigger = this.escapeXml(popup.trigger) === 'hover' ? ['hover', 'focus'] : ['focus'];
        const popupContent = (<Popover id={popup.id}>
        <Popover.Content className="popup__content">{contentNext()}</Popover.Content>
      </Popover>);
        return (<OverlayTrigger trigger={trigger} placement="top" overlay={popupContent}>
        <span tabIndex={0} role="button" className={`popup__anchorText${trigger.includes('hover') ? '' : ' popup__click'}`}>
          {anchorNext()}
        </span>
      </OverlayTrigger>);
    }
    text(context, textEntity) {
        return this.wrapWithMarks(textEntity.text, textEntity);
    }
    unsupported(_context, x) {
        console.error('Content element ' + JSON.stringify(x) + ' is invalid and could not display.');
        return <div className="content invalid">Content element is invalid</div>;
    }
}
//# sourceMappingURL=html.jsx.map