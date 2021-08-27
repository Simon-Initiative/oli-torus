import chroma from 'chroma-js';
import Delta from 'quill-delta';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import ReactQuill from 'react-quill';
import { parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import { AuthorPartComponentProps } from '../types/parts';
import Markup from './Markup';
import { convertJanusToQuill, convertQuillToJanus } from './quill-utils';
import { TextFlowModel } from './schema';

export interface MarkupTree {
  tag: string;
  href?: string;
  src?: string;
  target?: string;
  style?: any;
  text?: string;
  children?: MarkupTree[];
}

export const getStylesToOverwrite = (node: MarkupTree, child: MarkupTree, fontSize?: any) => {
  const style: any = {};
  if (
    (node.style.styleName === 'Heading' || node.style.styleName === 'Title') &&
    node.children?.length === 1 &&
    child.tag === 'span'
  ) {
    // PMP-526
    style.backgroundColor = '';
  }
  if (node.tag === 'p' && child.tag === 'span' && child.style.color === '#000000') {
    style.color = 'inherit';
  }
  if (!(child.style && child.style.fontSize) && fontSize) {
    style.fontSize = `${fontSize}px`;
  }
  return style;
};

export const renderFlow = (
  key: string,
  treeNode: MarkupTree,
  styleOverrides: any,
  state: any = {},
  fontSize?: any,
  specialTag?: string,
) => {
  // clone styles
  const styles: any = { ...treeNode.style };
  // loop override styles
  Object.keys(styleOverrides).forEach((s) => {
    // override styles
    styles[s] = styleOverrides[s];
  });
  // if style have 'baselineShift = superscript' or 'baselineShift = subscript'
  // need to handle them separately
  let customTag = '';
  if (styles?.baselineShift === 'superscript') {
    customTag = 'sup';
  } else if (styles?.baselineShift === 'subscript') {
    customTag = 'sub';
  }
  return (
    <Markup
      key={key}
      tag={specialTag || treeNode.tag}
      href={treeNode.href}
      src={treeNode.src}
      target={treeNode.target}
      style={styles}
      text={treeNode.text}
      state={state}
      displayRawText={true}
    >
      {treeNode.children &&
        treeNode.children.map((child, index) => {
          return renderFlow(
            `${key}_${index}`,
            child,
            getStylesToOverwrite(treeNode, child, fontSize),
            state,
            fontSize,
            customTag,
          );
        })}
    </Markup>
  );
};

const TextFlowAuthor: React.FC<AuthorPartComponentProps<TextFlowModel>> = (props) => {
  const { model, configuremode } = props;
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const initialize = useCallback(async (pModel) => {
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, []);

  const {
    x = 0,
    y = 0,
    width,
    z = 0,
    customCssClass,
    nodes,
    palette,
    fontSize,
    height,
    overrideWidth = true,
    overrideHeight = false,
  } = model;

  const styles: any = {
    wordWrap: 'break-word',
    lineHeight: 'inherit',
  };
  if (overrideWidth) {
    styles.width = width;
  }
  if (overrideHeight) {
    styles.height = height;
  }
  if (fontSize) {
    styles.fontSize = `${fontSize}px`;
  }
  if (palette) {
    styles.borderWidth = `${palette?.lineThickness ? palette?.lineThickness + 'px' : '1px'}`;
    (styles.borderStyle = 'solid'),
      (styles.borderColor = `rgba(${
        palette?.lineColor || palette?.lineColor === 0
          ? chroma(palette?.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${palette?.lineAlpha})`),
      (styles.backgroundColor = `rgba(${
        palette?.fillColor || palette?.fillColor === 0
          ? chroma(palette?.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${palette?.fillAlpha})`);
  }

  // TODO: preprocess model to find required variables and/or expressions
  // using onInit to wait for initial state to be sent, and hold rendering
  // until isReady (and also then fire onReady)
  // send pre-calculated map of required values to Markup

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  // due to custom elements, objects will be JSON
  let tree: MarkupTree[] = [];
  if (nodes && typeof nodes === 'string') {
    tree = JSON.parse(nodes as string) as MarkupTree[];
  } else if (Array.isArray(nodes)) {
    tree = nodes;
  }
  const styleOverrides: any = {};
  if (width) {
    styleOverrides.width = width;
  }
  if (fontSize) {
    styleOverrides.fontSize = `${fontSize}px`;
  }

  const Editor = () => (
    <div
      onClick={(e) => {
        e.stopPropagation();
      }}
      style={{ minWidth: 400, minHeight: 400, backgroundColor: '#fff' }}
    >
      <ReactQuill
        modules={{
          toolbar: [
            ['bold', 'italic', 'underline', 'strike'], // toggled buttons
            ['blockquote', 'code-block'],

            [{ header: 1 }, { header: 2 }], // custom button values
            [{ list: 'ordered' }, { list: 'bullet' }],
            [{ script: 'sub' }, { script: 'super' }], // superscript/subscript
            [{ indent: '-1' }, { indent: '+1' }], // outdent/indent
            [{ direction: 'rtl' }], // text direction

            [{ size: ['small', false, 'large', 'huge'] }], // custom dropdown
            [{ header: [1, 2, 3, 4, 5, 6, false] }],

            [{ color: [] }, { background: [] }], // dropdown with defaults from theme
            [{ font: [] }],
            [{ align: [] }],

            ['clean'], // remove formatting button
          ],
        }}
        defaultValue={convertJanusToQuill(tree) as any}
        onChange={(content, delta, source, editor) => {
          console.log('quill changes', { content, delta, source, editor });
          const janusText = convertQuillToJanus(new Delta(editor.getContents().ops));
          console.log('JANUS TEXT', janusText);
        }}
      />
    </div>
  );

  const renderIt = parseBoolean(configuremode) ? (
    ReactDOM.createPortal(<Editor />, document.getElementById('part-portal-47') as Element)
  ) : (
    <React.Fragment>
      <style>
        {/*
        note these custom styles are for dealing with KIP / legacy content * that are applied
        we may need to do something else for the new theme and/or the themeless?
      */}
        {`
        <link rel="stylesheet" href="https://cdn.quilljs.com/1.3.6/quill.snow.css" />

        .text-flow-authoring-preview {
          font-size: 13px;
        }
        .text-flow-authoring-preview p {
          margin: 0;
        }
      `}
      </style>
      <div className="text-flow-authoring-preview" style={styles}>
        {tree?.map((subtree: MarkupTree) =>
          renderFlow(`textflow-${guid()}`, subtree, styleOverrides, {}, fontSize),
        )}
      </div>
    </React.Fragment>
  );

  useEffect(() => {
    console.log('TF CONFIGURE MODE CHANGE', { configuremode });
  }, [configuremode]);

  return ready ? renderIt : null;
};

export const tagName = 'janus-text-flow';

export default TextFlowAuthor;
