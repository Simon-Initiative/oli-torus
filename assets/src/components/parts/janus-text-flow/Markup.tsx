import React, { Fragment, useEffect, useRef } from 'react';
import { Environment } from 'janus-script';
import { templatizeText } from 'adaptivity/scripting';
import guid from 'utils/guid';

// removes irrelevant styles
const styleFilter = (styles: any) => {
  // list of styles to remove
  const stylesToRemove = ['textAlignLast'];
  // duplicate style object
  const updatedStyles = { ...styles };
  // loop removal list
  stylesToRemove.forEach((remove) => delete updatedStyles[remove]);
  // return the goods
  return updatedStyles;
};

/*eslint-disable */
const Markup: React.FC<any> = ({
  tag,
  href,
  src,
  target,
  style = {},
  text = '',
  children,
  state = {},
  customCssClass = '',
  displayRawText = false,
  env = new Environment(),
}) => {
  /*eslint-enable */
  const el = useRef<any>(null);

  useEffect(() => {
    // this effect is needed to support global style overrides that are expecting things
    // to be like SS did it ex. .content P SPAN[style*="font-family:Arial;"]
    if (!el.current) {
      return;
    }
    const ogStyles = el.current.getAttribute('style');
    const formatted = ogStyles && ogStyles.replace(/: /g, ':');
    el.current.setAttribute('style', formatted || '');
  }, [style]);

  // mutate the original styles w/o triggering re-render
  const renderStyles = {
    ...styleFilter(style),
  };
  if (renderStyles.fontSize) {
    if (typeof renderStyles.fontSize === 'string') {
      // I believe that React style attribute fontSize can accept different units
      // but can't have the units omitted
      if (renderStyles.fontSize.match(/^[0-9]+$/)) {
        renderStyles.fontSize = parseFloat(renderStyles.fontSize);
      }
    }
  }
  if (renderStyles.backgroundColor === 'transparent') {
    // seems that SS does not apply backgroundColor if the values is transparent
    renderStyles.backgroundColor = '';
  }

  let processedText = text;
  // allow (authoring usually) skipping the template processing
  if (!displayRawText) {
    processedText = text?.length ? templatizeText(text, state, env) : text;
  }

  // eslint-disable-next-line
  if (!children.length) {
    // empty elements in HTML don't stay in the flow
    // add a non breaking space instead of nothing

    processedText = processedText.length < 2 && !processedText.trim() ? '\u00a0' : processedText;
    if (tag === 'span') {
      renderStyles.visibility = 'hidden';
    }
  }
  if (processedText.length !== processedText.trimLeft().length) {
    const noOfleadingSpaces = processedText.length - processedText.trimLeft().length;
    let leadingSpacePart = processedText.substring(0, noOfleadingSpaces);
    let actualText = processedText.substring(noOfleadingSpaces);
    leadingSpacePart = leadingSpacePart.replace(/ /g, '\u00a0');
    actualText = actualText.replace(/\s /g, ' \u00a0');
    processedText = leadingSpacePart + actualText;
    // check if text has leading and trailing spaces.
    //handling the leading blank spacecs in the span
  } else {
    processedText = processedText.replace(/\s /g, ' \u00a0');
  }

  // this is to support "legacy" SmartSparrow lessons
  let renderTag = tag;
  if (renderStyles.styleName) {
    // TODO:
    switch (renderStyles.styleName.toLowerCase()) {
      case 'body text':
        renderTag = 'p';
        break;
      case 'title':
        renderTag = 'h1';
        break;
      case 'heading':
        renderTag = 'h2';
        break;
      case 'sub-heading':
        renderTag = 'h3';
        break;
      case 'small text':
        renderTag = 'small';
        break;
      case 'subscript':
        renderTag = 'sub';
        break;
      case 'superscript':
        renderTag = 'sup';
        break;
    }
  }

  // fix key bug, TODO: use this for ID on the element (needed/useful)?
  const key = `${renderTag}-${guid()}`;

  // TODO: support MathJax
  // TODO: support templating in text
  // TODO: support tables, quotes, definition lists?? form elements???

  switch (renderTag) {
    case 'a':
      return (
        <a
          ref={el}
          key={key}
          className={customCssClass}
          href={href}
          target={target || '_blank'}
          style={{ ...renderStyles, display: 'inline' }}
        >
          {processedText}
          {children}
        </a>
      );
    case 'span':
      return (
        <span ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </span>
      );
    case 'strong':
    case 'b':
      return (
        <strong ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </strong>
      );
    case 'em':
    case 'i':
      return (
        <em ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </em>
      );
    case 'div':
      return (
        <div ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </div>
      );
    case 'h1':
      // because of the global injected override .content *
      // sets display: inline for everything... we need to fix it again
      if (!renderStyles.display) {
        renderStyles.display = 'block';
      }
      return (
        <h1 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h1>
      );
    case 'h2':
      return (
        <h2 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h2>
      );
    case 'h3':
      return (
        <h3 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h3>
      );
    case 'h4':
      return (
        <h4 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h4>
      );
    case 'h5':
      return (
        <h5 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h5>
      );
    case 'h6':
      return (
        <h6 ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </h6>
      );
    case 'p':
      // because of the global injected override .content *
      // sets display: inline for everything... we need to fix it again
      if (!renderStyles.display) {
        renderStyles.display = 'block';
      }
      // because of the global injected override .content *
      // sets line-height: 1.4 for everything
      if (!renderStyles.lineHeight) {
        renderStyles.lineHeight = 'normal';
      }
      //let's not do this for all P tags forces fontSize to be specified
      //PMP-1308 - Uncommenting this for fixing spacing issues. If lineHeight is not applied then SS sets it to 0px.
      //In future, if for some reason someone has to comment it, please make sure to check PMP-1308
      // FIXME: we can't do this because this will basically make all the text invisible
      // TODO: figure out how to do it both ways
      /* if (!renderStyles.fontSize) {
        renderStyles.fontSize = '0px';
      } */
      return (
        <p ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </p>
      );
    case 'sub':
      return (
        <sub ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </sub>
      );
    case 'sup':
      return (
        <sup ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </sup>
      );
    case 'small':
      if (!renderStyles.display) {
        renderStyles.display = 'inline';
      }
      return (
        <small ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </small>
      );
    case 'code':
      return (
        <code ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </code>
      );
    case 'blockquote':
      return (
        <blockquote ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </blockquote>
      );
    case 'ol':
      return (
        <ol ref={el} key={key} className={customCssClass} style={renderStyles}>
          {processedText}
          {children}
        </ol>
      );
    case 'ul':
      delete renderStyles.width;
      return (
        <ul
          ref={el}
          key={key}
          className={customCssClass}
          style={{ ...renderStyles, paddingLeft: '40px' }}
        >
          {processedText}
          {children}
        </ul>
      );
    case 'li':
      // eslint-disable-next-line
      let spanChildren: any[] = [];
      children.forEach((child: any) => {
        if (child.props.tag === 'p') {
          child.props.children.forEach((child: any) => {
            if (child.props.tag === 'span') {
              spanChildren.push(child);
            }
          });
        } else if (child.props.tag === 'span') {
          spanChildren.push(child);
        }
      });
      const listStyle = { ...renderStyles, display: 'list-item' };
      if (spanChildren.length === 1 && spanChildren[0].props.style.color && !listStyle.color) {
        listStyle.color = spanChildren[0].props.style.color;
      }
      return (
        <li ref={el} key={key} className={customCssClass} style={listStyle}>
          {processedText}
          {children}
        </li>
      );
    case 'br':
      return <br ref={el} key={key} className={customCssClass} />;
    case 'img':
      if (renderStyles?.width === 'auto') {
        renderStyles.width = '';
      }
      if (renderStyles?.height === 'auto') {
        renderStyles.height = '';
      }
      return (
        <img
          src={src}
          alt={`${text || ''}`}
          ref={el}
          key={key}
          className={customCssClass}
          style={renderStyles}
        />
      );
    case 'text':
      // this is a special case similar to xml text nodes
      // not expected to have children
      return <Fragment>{processedText || '\u00a0'}</Fragment>;
    default:
      return (
        <Fragment>
          {processedText}
          {children}
        </Fragment>
      );
  }
};

export default Markup;
