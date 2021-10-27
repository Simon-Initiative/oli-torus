import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import { MCQItem } from './MultipleChoiceQuestion';
import { McqModel } from './schema';
import { registerEditor, tagName as quillEditorTagName } from '../janus-text-flow/QuillEditor';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ html, tree, portal }) => {
  const quillProps: { tree?: any; html?: any } = {};
  console.log({ quillProps });

  if (tree) {
    quillProps.tree = JSON.stringify(tree);
  }
  if (html) {
    quillProps.html = html;
  }
  console.log('MCQ E RERENDER', { html, tree, portal });
  const E = () => (
    <div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>
  );

  return portal && ReactDOM.createPortal(<E />, portal);
});
const McqAuthor: React.FC<AuthorPartComponentProps<McqModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;

  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    multipleSelection,
    mcqItems,
    customCssClass,
    layoutType,
    overrideHeight = false,
  } = model;
  const styles: CSSProperties = {
    width,
  };
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const [textNodes, setTextNodes] = useState<any[]>([]);
  const [windowModel, setWindowModel] = useState<any>(model);
  const [ready, setReady] = useState<boolean>(false);
  const [currentIndex, setCurrentIndex] = useState<number>(0);
  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const handleNotificationSave = useCallback(async () => {
    const modelClone = clone(model);
    mcqItems[currentIndex].nodes = textNodes;
    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
  }, [model, textNodes, currentIndex, mcqItems]);

  const [portalEl, setPortalEl] = useState<HTMLElement | null>(null);
  const initialize = useCallback(async (pModel) => {
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, []);
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

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  useEffect(() => {
    registerEditor();
  }, []);

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
                /*
                console.log('TF:NotificationType.CONFIGURE_SAVE', { partId, payload }); */
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

  useEffect(() => {
    const handleEditorSave = (e: any) => {
      /* console.log('TF EDITOR SAVE'); */
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload, callback } = e.detail;
      /* console.log('TF EDITOR SAVE', { payload, callback, props }); */
      const modelClone = clone(model);
      modelClone.nodes = payload;
      // optimistic update
      //setModel(modelClone);
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
      const { payload, callback } = e.detail;
      /* console.log('MCQ EDITOR CHANGE', { payload, callback }); */
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
  const options: any[] = mcqItems?.map((item: any, index: number) => ({
    ...item,
    index: index,
    value: index + 1,
  }));

  let columns = 1;
  if (customCssClass === 'two-columns') {
    columns = 2;
  }
  if (customCssClass === 'three-columns') {
    columns = 3;
  }
  if (customCssClass === 'four-columns') {
    columns = 4;
  }
  const [tree, setTree] = useState<MarkupTree[]>([]);
  const [htmlPreview, setHtmlPreview] = useState<string>('');
  const onClick = (index: any, option: number) => {
    if (mcqItems[index].nodes && typeof mcqItems[index].nodes === 'string') {
      setTree(JSON.parse(mcqItems[index].nodes as unknown as string) as MarkupTree[]);
    } else if (Array.isArray(mcqItems[index].nodes)) {
      setTree(mcqItems[index].nodes);
    }
    setTextNodes(mcqItems[index].nodes);
    onConfigure({ id, configure: true, context: { fullscreen: false } });
    setInConfigureMode(true);
  };

  return (
    <React.Fragment>
      {inConfigureMode && portalEl && <Editor html={htmlPreview} tree={tree} portal={portalEl} />}
      {
        <div data-janus-type={tagName} style={styles} className={`mcq-input`}>
          <style>
            {`
          .mcq-input>div {
            margin: 1px 6px 10px 0 !important;
            display: block;
            position: static !important;
            min-height: 20px;
            line-height: normal !important;
            vertical-align: middle;
          }
          .mcq-input>div>label {
            margin: 0 !important;
          }
          .mcq-input>br {
            display: none !important;
          }
        `}
          </style>
          {!inConfigureMode &&
            options?.map((item, index) => (
              <MCQItem
                index={index}
                key={`${id}-item-${index}`}
                totalItems={options.length}
                layoutType={layoutType}
                itemId={`${id}-item-${index}`}
                groupId={`mcq-${id}`}
                val={item.value}
                {...item}
                x={0}
                y={0}
                overrideHeight={overrideHeight}
                disabled={false}
                multipleSelection={multipleSelection}
                columns={columns}
                onClick={onClick}
              />
            ))}
        </div>
      }
    </React.Fragment>
  );
};

export const tagName = 'janus-mcq';

export default McqAuthor;
