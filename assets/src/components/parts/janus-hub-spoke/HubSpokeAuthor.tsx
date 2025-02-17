import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import ConfirmDelete from '../../../../src/apps/authoring/components/Modal/DeleteConfirmationModal';
import { tagName as quillEditorTagName, registerEditor } from '../janus-text-flow/QuillEditor';
import { SpokeItems } from './HubSpoke';
import { hubSpokeModel } from './schema';

const HubSpokeAuthor: React.FC<AuthorPartComponentProps<hubSpokeModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;
  const {
    width,
    multipleSelection,
    spokeItems,
    verticalGap,
    customCssClass,
    layoutType,
    overrideHeight = false,
    showProgressBar,
  } = model;
  const styles: CSSProperties = {
    width,
  };

  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  const [showConfigureMode, setShowConfigureMode] = useState<boolean>(false);
  const [editOptionClicked, setEditOptionClicked] = useState<boolean>(false);
  const [deleteOptionClicked, setDeleteOptionClicked] = useState<boolean>(false);
  const [textNodes, setTextNodes] = useState<string>('');
  const [ready, setReady] = useState<boolean>(false);
  const [currentIndex, setCurrentIndex] = useState<number>(0);
  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const handleNotificationSave = useCallback(async () => {
    const modelClone = clone(model);
    if (deleteOptionClicked) {
      modelClone.spokeItems.splice(currentIndex, 1);
    } else {
      modelClone.spokeItems[currentIndex].nodes = textNodes;
    }
    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);

    setEditOptionClicked(false);
    setDeleteOptionClicked(false);
  }, [model, textNodes, currentIndex, spokeItems, deleteOptionClicked, editOptionClicked]);

  const initialize = useCallback(async (pModel) => {
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, []);

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
  const options: any[] = spokeItems?.map((item: any, index: number) => ({
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
  const onClick = (index: any, option: number) => {
    setCurrentIndex(index);
    if (option === 1) {
      setEditOptionClicked(true);
      setDeleteOptionClicked(false);
      setTextNodes(spokeItems[index].nodes);

      onConfigure({ id, configure: true, context: { fullscreen: false } });
    } else if (option === 3) {
      setEditOptionClicked(false);
      setDeleteOptionClicked(false);
      const modelClone = clone(model);
      if (deleteOptionClicked) {
        modelClone.spokeItems.splice(index, 1);
      } else {
        modelClone.spokeItems.splice(index + 1, 0, {
          nodes: `Option ${spokeItems.length + 1}`,
          scoreValue: 0,
          index: spokeItems.length,
          value: spokeItems.length,
          targetScreen: '',
          destinationActivityId: '',
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
      {
        <div data-janus-type={tagName} style={styles} className={`hub-spoke spoke-${layoutType}`}>
          <style>
            {`

              .spoke-horizontalLayout .hub-spoke-item {
                box-sizing: border-box;
                margin-left: 0px;
                margin-right: 6px;
              }
              .spoke-horizontalLayout .progress-bar {
                width: 25% !important;
                margin-left: auto;
                margin-right: 8px !important;
              }
              .spoke-horizontalLayout {
                box-sizing: border-box;
                margin-left: 0px;
                margin-right: 0px;
              }
              .mcq-input > div > label {
                margin: 0 !important;
              }
              .mcq-input > br {
                display: none !important;
              }
              .hub-spoke button {
                color: white !important;
                min-width: 100px;
                height: auto !important;
                min-height: 44px;
                background-color: #006586;
                border-radius: 3px;
                border: none;
                padding: 10px 20px;
                cursor: pointer;
              }
              .hub-spoke {
                border: none !important;
                padding: 0px;

                > div {
                  display: block;
                  position: static !important;
                  margin: 0 9px 15px 0;
                  min-height: 20px;
                }
                > div:last-of-type {
                  margin-right: 0;
                }
                p {
                  margin: 0px;
                }
                > br {
                  display: none !important;
                }

                //Horizontal
                .mcq-wrap > div,
                .mcq-wrap label,
                .mcq-wrap label div,
                .mcq-wrap p {
                  display: inline-block !important;
                }
                .mcq-wrap > div {
                  margin-right: 10px !important;
                }
              }
        `}
          </style>
          {options?.map((item, index) => (
            <SpokeItems
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
          {showProgressBar && (
            <div className="space-y-5 progress-bar" style={{ width: '96%' }}>
              <div>
                <div className="mb-2 flex justify-between items-center">
                  <h3 className="text-sm font-semibold text-gray-800 dark:text-white">Progress</h3>
                  <span className="text-sm text-gray-800 dark:text-white">
                    <b>00/{options?.length}</b>
                  </span>
                </div>
                <div
                  className="flex w-full h-2 bg-gray-200 rounded-full overflow-hidden dark:bg-neutral-700"
                  role="progressbar"
                >
                  <div
                    className="flex flex-col justify-center rounded-full overflow-hidden bg-body-dark-600 text-xs text-white text-center whitespace-nowrap transition duration-500 dark:bg-blue-500"
                    style={{ width: '25%' }}
                  ></div>
                </div>
              </div>
            </div>
          )}
          {showConfirmDelete && (
            <ConfirmDelete
              show={showConfirmDelete}
              elementType="Spoke Option"
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
export const tagName = 'janus-hub-spoke';

export default HubSpokeAuthor;
