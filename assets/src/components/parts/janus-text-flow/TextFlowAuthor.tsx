import React, { useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import chroma from 'chroma-js';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import { AuthorPartComponentProps } from '../types/parts';
import Markup from './Markup';
import { tagName as quillEditorTagName, registerEditor } from './QuillEditor';
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

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ html, tree, portal }) => {
  const quillProps: { tree?: any; html?: any } = {};
  if (tree) {
    quillProps.tree = JSON.stringify(tree);
  }
  if (html) {
    quillProps.html = html;
  }
  /* console.log('E RERENDER', { html, tree, portal }); */
  const E = () => (
    <div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>
  );

  return portal && ReactDOM.createPortal(<E />, portal);
});

const TextFlowAuthor: React.FC<AuthorPartComponentProps<TextFlowModel>> = (props) => {
  const { configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));

  const htmlPreviewRef = useRef<any>(null);
  const [htmlPreview, setHtmlPreview] = useState<string>('');

  const [model, setModel] = useState<TextFlowModel>(props.model);
  const [textNodes, setTextNodes] = useState<any[]>(props.model.nodes);

  useEffect(() => {
    setModel(props.model);
  }, [props.model]);

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
    width,
    nodes,
    palette,
    fontSize,
    height,
    overrideWidth = true,
    overrideHeight = false,
    padding = '',
  } = model;

  const styles: any = {
    wordWrap: 'break-word',
    lineHeight: 'inherit',
  };
  if (overrideWidth) {
    styles.width = width;
  }
  if (padding?.trim()?.length) {
    styles.padding = padding;
  }
  if (overrideHeight) {
    styles.height = height;
  }
  if (fontSize) {
    styles.fontSize = `${fontSize}px`;
  }

  if (palette) {
    if (palette.useHtmlProps) {
      styles.backgroundColor = palette.backgroundColor;
      styles.borderColor = palette.borderColor;
      styles.borderWidth = palette.borderWidth;
      styles.borderStyle = palette.borderStyle;
      styles.borderRadius = palette.borderRadius;
    } else {
      styles.borderWidth = `${palette.lineThickness ? palette.lineThickness + 'px' : 0}`;
      styles.borderRadius = 0;
      styles.borderStyle = palette.lineStyle === 0 ? 'none' : 'solid';
      let borderColor = 'transparent';
      if (palette.lineColor! >= 0) {
        borderColor = chroma(palette.lineColor || 0)
          .alpha(palette.lineAlpha || 0)
          .css();
      }
      styles.borderColor = borderColor;

      let bgColor = 'transparent';
      if (palette.fillColor! >= 0) {
        bgColor = chroma(palette.fillColor || 0)
          .alpha(palette.fillAlpha?.toString() === 'NaN' ? 0 : palette.fillAlpha || 0)
          .css();
      }
      styles.backgroundColor = bgColor;
    }
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
      const { payload } = e.detail;
      // console.log('TF EDITOR SAVE', { payload, callback, props });
      const modelClone = clone(model);
      modelClone.nodes = payload;
      // optimistic update
      setModel(modelClone);
      onSaveConfigure({
        id,
        snapshot: modelClone,
      });
    };

    const handleEditorCancel = () => {
      if (!inConfigureMode) {
        return;
      } // not mine
      // console.log('TF EDITOR CANCEL');
      setInConfigureMode(false);
      onCancelConfigure({ id });
    };

    const handleEditorChange = (e: any) => {
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload } = e.detail;
      // console.log('TF EDITOR CHANGE', { payload, callback });
      setTextNodes(payload.value);
    };

    if (inConfigureMode) {
      document.addEventListener(`${quillEditorTagName}-change`, handleEditorChange);
      document.addEventListener(`${quillEditorTagName}-save`, handleEditorSave);
      document.addEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    }

    return () => {
      document.removeEventListener(`${quillEditorTagName}-change`, handleEditorChange);
      document.removeEventListener(`${quillEditorTagName}-save`, handleEditorSave);
      document.removeEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    };
  }, [ready, inConfigureMode, model]);

  const handleNotificationSave = useCallback(async () => {
    /* console.log('TF:NOTIFYSAVE', { id, model, textNodes }); */
    const modelClone = clone(model);
    modelClone.nodes = textNodes;
    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
  }, [model, textNodes]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_SAVE,
      NotificationType.CONFIGURE_CANCEL,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification event [PopupAuthor]`, payload); */
        if (!payload) {
          // if we don't have anything, we won't even have an id to know who it's for
          // for these events we need something, it's not for *all* of them
          return;
        }
        switch (notificationType) {
          case NotificationType.CONFIGURE:
            {
              const { partId, configure } = payload;
              if (partId === id) {
                /* console.log('TF:NotificationType.CONFIGURE', { partId, configure }); */
                // if it's not us, then we shouldn't be configuring
                setInConfigureMode(configure);
                if (configure) {
                  onConfigure({ id, configure, context: { fullscreen: false } });
                }
              }
            }
            break;
          case NotificationType.CONFIGURE_SAVE:
            {
              const { id: partId } = payload;
              if (partId === id) {
                /* console.log('TF:NotificationType.CONFIGURE_SAVE', { partId }); */
                handleNotificationSave();
              }
            }
            break;
          case NotificationType.CONFIGURE_CANCEL:
            {
              const { id: partId } = payload;
              if (partId === id) {
                /* console.log('TF:NotificationType.CONFIGURE_CANCEL', { partId }); */
                setInConfigureMode(false);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify, handleNotificationSave]);

  const [portalEl, setPortalEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    // timeout to give modal a moment to load
    setTimeout(() => {
      const el = document.getElementById(props.portal);
      // console.log('portal changed', { el, p: props.portal });
      if (el) {
        setPortalEl(el);
      }
    }, 10);
  }, [inConfigureMode, props.portal]);

  /* console.log('TF RENDER', { id, htmlPreview }); */

  if (htmlPreviewRef.current) {
    const latestPreview = htmlPreviewRef.current?.innerHTML || '';
    if (latestPreview !== htmlPreview) {
      setHtmlPreview(latestPreview);
    }
  }

  const renderIt =
    inConfigureMode && portalEl ? (
      <Editor html={htmlPreview} tree={tree} portal={portalEl} />
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
