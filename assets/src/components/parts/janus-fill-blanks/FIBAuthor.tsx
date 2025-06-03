import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import Select2 from 'react-select2-wrapper';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import { registerEditor } from '../janus-text-flow/QuillEditor';
import { tagName as quillEditorTagName } from '../janus-text-flow/QuillEditor';
import {
  convertFIBContentToQuillNodes,
  extractFormattedHTMLFromQuillNodes,
  generateFIBStructure,
  transformOptionsToNormalized,
} from './FIBUtils';
import { FIBModel } from './schema';

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ html, tree, portal, customOptions }) => {
  const quillProps: {
    tree?: any;
    html?: any;
    showimagecontrol?: boolean;
    showfibinsertoptioncontrol?: boolean;
    options?: any;
  } = {};
  quillProps.tree = JSON.stringify(tree);
  quillProps.showfibinsertoptioncontrol = true;
  quillProps.options = JSON.stringify(transformOptionsToNormalized(customOptions));
  const E = () => (
    <div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>
  );

  return portal && ReactDOM.createPortal(<E />, portal);
});

const FIBAuthor: React.FC<AuthorPartComponentProps<FIBModel>> = (props) => {
  const { configuremode, id, onConfigure, onSaveConfigure } = props;
  const [model, setModel] = useState<any>(props.model);
  const [ready, setReady] = useState<boolean>(false);
  const [isContentModified, setIsContentModified] = useState<boolean>(false);
  const [updatedContent, setUpdatedContent] = useState<any>([]);
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const [textNodes, setTextNodes] = useState<any[]>([]);
  const [finalContent, setFinalContent] = useState<any>([]);
  const [finalElement, setFinalElement] = useState<any>([]);
  const { content, elements, customCss } = model;

  const styles: CSSProperties = {
    borderRadius: '5px',
    fontFamily: 'revert',
  };

  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  useEffect(() => {
    setModel(props.model);
  }, [props.model]);

  // Whenever `textNodes` or `finalElement` changes, extract the formatted plain-text content from Quill nodes,
  // generate the corresponding FIB structure by mapping it to existing blank elements (finalElement),
  // and update the state with the parsed result.
  useEffect(() => {
    if (textNodes?.length) {
      const collectedText = extractFormattedHTMLFromQuillNodes(textNodes);
      const finalcontent = generateFIBStructure(collectedText, 'map', finalElement);
      setFinalContent(finalcontent);
    }
  }, [textNodes, finalElement]);

  const initialize = useCallback(async (pModel) => {
    setReady(true);
  }, []);

  useEffect(() => {
    const convertedText = convertFIBContentToQuillNodes(content, elements);
    setUpdatedContent(convertedText);

    setFinalContent({ content, elements });
  }, [content, elements]);

  useEffect(() => {
    // all activities *must* emit onReady
    registerEditor();
    initialize(model);
    props.onReady({ id: `${props.id}` });
  }, []);

  const handleNotificationSave = useCallback(async () => {
    if (isContentModified) {
      const modelClone = clone(model);
      modelClone.content = finalContent.content;
      modelClone.elements = finalElement;
      await onSaveConfigure({ id, snapshot: modelClone });
      setIsContentModified(false);
    }
    setInConfigureMode(false);
  }, [model, finalContent, finalElement, isContentModified]);

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
                handleNotificationSave();
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
  }, [props.notify, inConfigureMode, finalContent]);

  useEffect(() => {
    const handleEditorSave = (e: any) => {
      if (!inConfigureMode) {
        return;
      }
    };

    const handleEditorCancel = () => {
      if (!inConfigureMode) {
        return;
      } // not mine
      setInConfigureMode(false);
    };

    const handleEditorChange = (e: any) => {
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload } = e.detail;
      setIsContentModified(true);
      if (payload?.value) {
        setTextNodes(payload.value);
      }
      setFinalElement(payload.options);
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
      if (el) {
        setPortalEl(el);
      }
    }, 10);
  }, [inConfigureMode, finalContent, props.portal]);

  const contentList = content?.map(
    (contentItem: { [x: string]: any; insert: any; dropdown: any }, index: number) => {
      if (!elements?.length) return;

      const insertList: any[] = [];
      let insertEl: any;

      if (contentItem.insert) {
        // contentItem.insert is always a string
        const htmlString = contentItem?.insert?.replace(/\n/g, '<br />');
        insertList.push(
          <span dangerouslySetInnerHTML={{ __html: htmlString }} key={`text-${index}`} />,
        );
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
        <Editor type={1} html="" tree={updatedContent} customOptions={elements} portal={portalEl} />
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
