import chroma from 'chroma-js';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import { AuthorPartComponentProps } from '../types/parts';
import Markup from './Markup';
import { registerEditor, tagName as quillEditorTagName } from './QuillEditor';
import { TextFlowModel } from './schema';

export interface MarkupTree {
  tag: string;
  href?: string;
  src?: string;
  target?: string;
  style?: any;
  text?: string;
  children?: MarkupTree[];
  customCssClass?: string;
}

export const getStylesToOverwrite = (node: MarkupTree, child: MarkupTree, fontSize?: any) => {
  const style: any = {};
  if (!node.style) {
    return style;
  }
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

  // disable hyperlinks and replace with a faux hyperlink
  // because we don't want to navigate in authoring mode
  if (treeNode.tag === 'a') {
    specialTag = 'span';
    styles.color = '#0000ff';
    styles.textDecoration = 'underline';
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
      customCssClass={treeNode.customCssClass}
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
  const { model, configuremode, onCancelConfigure, onSaveConfigure } = props;
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));

  const htmlPreviewRef = useRef<any>(null);
  const [htmlPreview, setHtmlPreview] = useState<string>('');

  useEffect(() => {
    console.log('TF REF CHANGE', htmlPreviewRef.current);
    if (htmlPreviewRef.current) {
      setHtmlPreview(htmlPreviewRef.current?.innerHTML || '');
    }
  }, [htmlPreviewRef.current]);

  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

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

  useEffect(() => {
    registerEditor();
  }, []);

  useEffect(() => {
    const handleEditorSave = (e: any) => {
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload, callback } = e.detail;
      console.log('TF EDITOR SAVE', { payload, callback, props });
      const modelClone = clone(model);
      modelClone.nodes = payload;
      onSaveConfigure({
        id,
        snapshot: modelClone,
      });
    };

    const handleEditorCancel = () => {
      if (!inConfigureMode) {
        return;
      } // not mine
      console.log('TF EDITOR CANCEL');
      setInConfigureMode(false);
      onCancelConfigure({ id });
    };

    if (inConfigureMode) {
      document.addEventListener(`${quillEditorTagName}-save`, handleEditorSave);
      document.addEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    }

    return () => {
      document.removeEventListener(`${quillEditorTagName}-save`, handleEditorSave);
      document.removeEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    };
  }, [ready, inConfigureMode]);

  const Editor = () =>
    React.createElement(quillEditorTagName, {
      /* tree: JSON.stringify(tree), */ // easier to let the editor do it via HTML
      html: htmlPreview,
    });

  const renderIt = inConfigureMode ? (
    ReactDOM.createPortal(<Editor />, document.getElementById(props.portal) as Element)
  ) : (
    <React.Fragment>
      <style>
        {/*
        note these custom styles are for dealing with KIP / legacy content * that are applied
        we may need to do something else for the new theme and/or the themeless?
      */}
        {`
        .text-flow-authoring-preview {
          font-size: 13px;
        }
        .text-flow-authoring-preview p {
          margin: 0;
        }
      `}
      </style>
      <div ref={htmlPreviewRef} className="text-flow-authoring-preview" style={styles}>
        {tree?.map((subtree: MarkupTree) =>
          renderFlow(`textflow-${guid()}`, subtree, styleOverrides, {}, fontSize),
        )}
      </div>
    </React.Fragment>
  );

  return ready ? renderIt : null;
};

export const tagName = 'janus-text-flow';

export default TextFlowAuthor;
