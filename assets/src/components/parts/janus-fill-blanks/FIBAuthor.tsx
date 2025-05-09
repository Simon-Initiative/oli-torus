import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import Select2 from 'react-select2-wrapper';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { parseBoolean } from 'utils/common';
import { registerEditor } from '../janus-text-flow/QuillEditor';
import { tagName as quillEditorTagName } from '../janus-text-flow/QuillEditor';
import { FIBModel } from './schema';

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ html, tree, portal, optionType }) => {
  const quillProps: {
    tree?: any;
    html?: any;
    showimagecontrol?: boolean;
    showcustomoptioncontrol?: boolean;
    customoptiontype?: 'dropdown' | 'input';
  } = {};
  quillProps.tree = '[]';
  quillProps.showcustomoptioncontrol = true;
  quillProps.customoptiontype = optionType;
  console.log('E RERENDER', { html, tree, portal, quillProps });
  const E = () => (
    <div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>
  );

  return portal && ReactDOM.createPortal(<E />, portal);
});

const FIBAuthor: React.FC<AuthorPartComponentProps<FIBModel>> = (props) => {
  const { configuremode, id, model, onConfigure } = props;
  const [ready, setReady] = useState<boolean>(false);
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const { content, elements, customCss, optionType } = model;

  console.log({ optionType });
  const styles: CSSProperties = {
    borderRadius: '5px',
    fontFamily: 'revert',
  };

  useEffect(() => {
    console.log({ configuremode });
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const initialize = useCallback(async (pModel) => {
    setReady(true);
  }, []);

  useEffect(() => {
    // all activities *must* emit onReady

    registerEditor();
    initialize(model);
    props.onReady({ id: `${props.id}` });
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
        console.log(`${notificationType.toString()} notification event [PopupAuthor]`, payload);
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
                //handleNotificationSave();
              }
            }
            break;
          case NotificationType.CONFIGURE_CANCEL:
            {
              const { id: partId } = payload;
              if (partId === id) {
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
  }, [props.notify, inConfigureMode]);

  useEffect(() => {
    console.log({ inConfigureMode });
    const handleEditorSave = (e: any) => {};

    const handleEditorCancel = () => {
      console.log({ inConfigureMode });
      if (!inConfigureMode) {
        return;
      } // not mine
      // console.log('TF EDITOR CANCEL');
      setInConfigureMode(false);
      //onCancelConfigure({ id });
    };

    const handleEditorChange = (e: any) => {
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload } = e.detail;
      console.log({ payload });
      //setTextNodes(payload.value);
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

  const [portalEl, setPortalEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    // timeout to give modal a moment to load
    setTimeout(() => {
      const el = document.getElementById(props.portal);
      console.log('portal changed', { el, p: props.portal });
      if (el) {
        setPortalEl(el);
      }
    }, 10);
  }, [inConfigureMode, props.portal]);
  const contentList = content?.map(
    (contentItem: { [x: string]: any; insert: any; dropdown: any }) => {
      if (!elements?.length) return;

      const insertList: any[] = [];
      let insertEl: any;

      if (contentItem.insert) {
        // contentItem.insert is always a string
        insertList.push(<span dangerouslySetInnerHTML={{ __html: contentItem.insert }} />);
      } else if (contentItem.dropdown) {
        // get correlating dropdown from `elements`
        insertEl = elements.find((elItem: { key: any }) => elItem.key === contentItem.dropdown);
        if (insertEl) {
          // build list of options for react-select
          const optionsList = insertEl.options.map(
            ({ value: text, key: id }: { value: any; key: any }) => ({ id, text }),
          );

          insertList.push(
            <span className="dropdown-blot" tabIndex={-1}>
              <span className="dropdown-container" tabIndex={-1}>
                <Select2
                  className={`dropdown incorrect`}
                  name={insertEl.key}
                  data={optionsList}
                  aria-label="Make a selection"
                  options={{
                    minimumResultsForSearch: 10,
                    selectOnClose: false,
                  }}
                  disabled={true}
                />
              </span>
            </span>,
          );
        }
      } else if (contentItem['text-input']) {
        // get correlating inputText from `elements`
        insertEl = elements.find((elItem: { key: any }) => {
          return elItem.key === contentItem['text-input'];
        });
        if (insertEl) {
          const answerStatus = 'incorrect';

          insertList.push(
            <span className="text-input-blot">
              <span className={`text-input-container ${answerStatus}`} tabIndex={-1}>
                <input
                  name={insertEl.key}
                  className={`text-input disabled`}
                  type="text"
                  disabled={true}
                />
              </span>
            </span>,
          );
        }
      }
      return insertList;
    },
  );
  return (
    <React.Fragment>
      {inConfigureMode && portalEl && (
        <Editor type={1} html="" tree={contentList} portal={portalEl} optionType={optionType} />
      )}
      <div data-janus-type={tagName} style={styles} className={`fib-container`}>
        <style type="text/css">{`${customCss}`};</style>
        <div className="scene">
          <div className="app">
            <div className="editor ql-container ql-snow ql-disabled">
              <div
                className="ql-editor"
                data-gramm="false"
                contentEditable="false"
                suppressContentEditableWarning={true}
              >
                <p>{contentList}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </React.Fragment>
  );
};

export const tagName = 'janus-fill-blanks';

export default FIBAuthor;
