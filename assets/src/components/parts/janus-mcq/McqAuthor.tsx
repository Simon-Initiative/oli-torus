import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import ConfirmDelete from '../../../../src/apps/authoring/components/Modal/DeleteConfirmationModal';
import { tagName as quillEditorTagName, registerEditor } from '../janus-text-flow/QuillEditor';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import { MCQItem } from './MultipleChoiceQuestion';
import { McqModel } from './schema';

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ html, tree, portal, type }) => {
  const quillProps: { tree?: any; html?: any; showimagecontrol?: boolean } = {};
  if (tree) {
    quillProps.tree = JSON.stringify(tree);
  }
  if (html) {
    quillProps.html = html;
  }
  quillProps.showimagecontrol = true;
  if (type === 1) {
    const E = () => (
      <div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>
    );

    return portal && ReactDOM.createPortal(<E />, portal);
  }
});
const McqAuthor: React.FC<AuthorPartComponentProps<McqModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;

  const {
    width,
    multipleSelection,
    mcqItems,
    verticalGap,
    customCssClass,
    layoutType,
    overrideHeight = false,
  } = model;
  const styles: CSSProperties = {
    width,
  };

  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const [showConfigureMode, setShowConfigureMode] = useState<boolean>(false);
  const [editOptionClicked, setEditOptionClicked] = useState<boolean>(false);
  const [deleteOptionClicked, setDeleteOptionClicked] = useState<boolean>(false);
  const [textNodes, setTextNodes] = useState<any[]>([]);
  const [ready, setReady] = useState<boolean>(false);
  const [currentIndex, setCurrentIndex] = useState<number>(0);
  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const handleNotificationSave = useCallback(async () => {
    const modelClone = clone(model);
    if (deleteOptionClicked) {
      modelClone.mcqItems.splice(currentIndex, 1);
    } else {
      modelClone.mcqItems[currentIndex].nodes = textNodes;
    }
    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);

    setEditOptionClicked(false);
    setDeleteOptionClicked(false);
  }, [model, textNodes, currentIndex, mcqItems, deleteOptionClicked, editOptionClicked]);

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
              const { partId } = payload;
              if (partId === id) {
                setInConfigureMode(false);
                setShowConfigureMode(!showConfigureMode);
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
  }, [props.notify, handleNotificationSave, currentIndex, showConfigureMode]);

  useEffect(() => {
    const handleEditorSave = (e: any) => {};

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
  const onClick = (index: any, option: number) => {
    setCurrentIndex(index);
    if (option === 1) {
      setEditOptionClicked(true);
      setDeleteOptionClicked(false);
      if (mcqItems[index].nodes && typeof mcqItems[index].nodes === 'string') {
        setTree(JSON.parse(mcqItems[index].nodes as unknown as string) as MarkupTree[]);
      } else if (Array.isArray(mcqItems[index].nodes)) {
        setTree(mcqItems[index].nodes);
      }
      setTextNodes(mcqItems[index].nodes);

      onConfigure({ id, configure: true, context: { fullscreen: false } });
    } else if (option === 3) {
      setEditOptionClicked(false);
      setDeleteOptionClicked(false);
      const modelClone = clone(model);
      if (deleteOptionClicked) {
        modelClone.mcqItems.splice(index, 1);
      } else {
        modelClone.mcqItems.splice(index + 1, 0, {
          nodes: [
            {
              tag: 'p',
              style: {},
              children: [
                {
                  children: [{ children: [], tag: 'text', text: `Option ${mcqItems.length + 1}` }],
                  style: {
                    backgroundColor: 'transparent',
                    color: 'inherit',
                    fontSize: '16px',
                  },
                  tag: 'span',
                },
              ],
            },
          ],
          scoreValue: 0,
          index: mcqItems.length,
          value: mcqItems.length,
        });
      }
      onSaveConfigure({ id, snapshot: modelClone });
    } else {
      setShowConfirmDelete(true);
      setDeleteOptionClicked(true);
      setEditOptionClicked(false);
    }
  };
  const handleDeleteRule = () => {
    setShowConfirmDelete(false);
    handleNotificationSave();
  };
  return (
    <React.Fragment>
      {editOptionClicked && portalEl && <Editor type={1} html="" tree={tree} portal={portalEl} />}
      {
        <div data-janus-type={tagName} style={styles} className={`mcq-input mcq-${layoutType}`}>
          <style>
            {`
          .mcq-input>div {
            margin: 1px 6px 10px 0;
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
          {options?.map((item, index) => (
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
              verticalGap={verticalGap}
              overrideHeight={overrideHeight}
              disabled={false}
              multipleSelection={multipleSelection}
              columns={columns}
              onConfigOptionClick={onClick}
              configureMode={showConfigureMode}
            />
          ))}
          {showConfirmDelete && (
            <ConfirmDelete
              show={showConfirmDelete}
              elementType="MCQ Option"
              elementName="the Option"
              deleteHandler={() => handleDeleteRule()}
              cancelHandler={() => {
                setShowConfirmDelete(false);
              }}
            />
          )}
        </div>
      }
    </React.Fragment>
  );
};

export const tagName = 'janus-mcq';

export default McqAuthor;
