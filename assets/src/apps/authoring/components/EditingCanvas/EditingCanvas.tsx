import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { EntityId } from '@reduxjs/toolkit';
import { selectCustom } from 'apps/authoring/store/page/slice';
import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { NotificationType } from 'apps/delivery/components/NotificationContext';
import { useKeyDown } from 'hooks/useKeyDown';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import {
  selectBottomPanel,
  setCopiedPart,
  setCopiedPartActivityId,
  setRightPanelActiveTab,
} from '../../store/app/slice';
import {
  selectCurrentPartPropertyFocus,
  selectCurrentSelection,
  setCurrentPartPropertyFocus,
  setCurrentSelection,
} from '../../store/parts/slice';
import { RightPanelTabs } from '../RightMenu/RightMenu';
import AuthoringActivityRenderer from './AuthoringActivityRenderer';
import ConfigurationModal from './ConfigurationModal';
import StagePan from './StagePan';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const _bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const _currentPartSelection = useSelector(selectCurrentSelection);
  const _currentPartPropertyFocus = useSelector(selectCurrentPartPropertyFocus);
  const _currentLessonCustom = useSelector(selectCustom);
  const [_currentActivity] = (currentActivityTree || []).slice(-1);

  const [currentActivityId, setCurrentActivityId] = useState<EntityId>('');
  const [customInterfaceSettings, setCustomInterfaceSettings] = useState<string>('default');
  const [showConfigModal, setShowConfigModal] = useState<boolean>(false);
  const [configModalFullscreen, setConfigModalFullscreen] = useState<boolean>(false);
  const [configModalCustomClassName, setConfigModalCustomClassName] = useState<string>('');
  const [configPartId, setConfigPartId] = useState<string>('');
  const [currentSelectedPartId, setCurrentSelectedPartId] = useState<string>('');
  const [notificationStream, setNotificationStream] = useState<{
    stamp: number;
    type: NotificationType;
    payload: any;
  } | null>(null);

  useEffect(() => {
    let current = null;
    if (currentActivityTree) {
      current = currentActivityTree.slice(-1)[0];
    }
    setCurrentActivityId(current?.id || '');
  }, [currentActivityTree]);

  const _handleSelectionChanged = (selected: string[]) => {
    const [first] = selected;
    /* console.log('[handleSelectionChanged]', { selected }); */
    const newSelection = first || '';
    dispatch(setCurrentSelection({ selection: newSelection }));
    const selectedTab = newSelection ? RightPanelTabs.COMPONENT : RightPanelTabs.SCREEN;
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: selectedTab }));
  };

  const handlePositionChanged = async (activityId: string, partId: string, dragData: any) => {
    // if we haven't moved, no point
    if (dragData.deltaX === 0 && dragData.deltaY === 0) {
      return false;
    }

    // at this point, this handler's reference will have been set no matter the deps
    // to a previous version, because the reference is passed into a DOM event
    // when it is wired to listen to custom element events
    // so we have to be able to simply dispatch the change to something that will
    // be able to access the latest activity state

    /* console.log('[handlePositionChanged]', { activityId, partId, dragData }); */

    const newPosition = { x: dragData.x, y: dragData.y };

    dispatch(
      updatePart({ activityId, partId, changes: { custom: newPosition }, mergeChanges: true }),
    );

    return newPosition;
  };

  const handlePartSelect = async (id: string) => {
    /* console.log('[handlePartSelect]', { id }); */
    dispatch(setCurrentSelection({ selection: id }));
    setCurrentSelectedPartId(id);
    dispatch(
      setRightPanelActiveTab({
        rightPanelActiveTab: !id.length ? RightPanelTabs.SCREEN : RightPanelTabs.COMPONENT,
      }),
    );
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
    return true;
  };

  const handlePartCopy = async (part: any) => {
    dispatch(setCopiedPart({ copiedPart: part }));
    if (currentActivityTree) {
      // Global 'currentActivityId' was not up to date with the current selected activity if when we select a subscreen from a layer
      // so we will get the currentActivity from the currentActivityTree and then set the setCopiedPartActivityId
      const [currentActivity] = currentActivityTree.slice(-1);
      dispatch(setCopiedPartActivityId({ copiedPartActivityId: currentActivity.id }));
    } else {
      // we don't need this. Just for any fail safe I did't remove this but ideally the code will never reach here.
      dispatch(setCopiedPartActivityId({ copiedPartActivityId: currentActivityId }));
    }
    return true;
  };
  useEffect(() => {
    let interfaceSettingClass = '';
    if (_currentLessonCustom.grid) {
      interfaceSettingClass += ' show-grid';
    }
    if (_currentLessonCustom.columnGuides) {
      interfaceSettingClass += ' show-column-guide';
    }
    if (_currentLessonCustom.centerpoint) {
      interfaceSettingClass += ' show-center';
    }
    if (_currentLessonCustom.rowGuides) {
      interfaceSettingClass += ' show-row-guide';
    }
    setCustomInterfaceSettings(interfaceSettingClass);
  }, [_currentLessonCustom]);
  const handleStageClick = (e: any) => {
    if (e.target.className !== 'aa-stage') {
      return;
    }
    /* console.log('[handleStageClick]', e); */
    dispatch(setCurrentSelection({ selection: '' }));

    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  };

  // TODO: rename first param to partId
  const handlePartConfigure = async (part: any, context: any) => {
    /* console.log('[handlePartConfigure]', { part, context }); */
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
    const { fullscreen = false, customClassName = '' } = context;
    setConfigModalFullscreen(fullscreen);
    setConfigModalCustomClassName(customClassName);
    setConfigPartId(part);
    setShowConfigModal(true);
  };

  const handlePartCancelConfigure = async (partId: string) => {
    /* console.log('[handlePartCancelConfigure]', { partId }); */
    setConfigPartId('');
    setConfigModalFullscreen(false);
    setShowConfigModal(false);
  };

  const handlePartSaveConfigure = async (partId: string) => {
    /* console.log('[handlePartSaveConfigure]', { partId }); */
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  };

  // console.log('EC: RENDER', { layers });

  useEffect(() => {
    dispatch(setCurrentSelection({ selection: '' }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  }, [currentActivityId]);

  useKeyDown(
    () => {
      if (currentSelectedPartId && !configPartId?.length && _currentPartPropertyFocus) {
        setNotificationStream({
          stamp: Date.now(),
          type: NotificationType.CHECK_SHORTCUT_ACTIONS,
          payload: { id: currentSelectedPartId, type: 'Delete' },
        });
      }
    },
    ['Delete', 'Backspace'],
    {},
    [currentSelectedPartId, configPartId, _currentPartPropertyFocus],
  );

  useKeyDown(
    () => {
      if (currentSelectedPartId && !configPartId?.length && _currentPartPropertyFocus) {
        setNotificationStream({
          stamp: Date.now(),
          type: NotificationType.CHECK_SHORTCUT_ACTIONS,
          payload: { id: currentSelectedPartId, type: 'Copy' },
        });
      } else if (!_currentPartPropertyFocus) {
        //if user first copies a part and then before pasting it, if they click on the properties and do a cntrl+c, we need to clear the existing cntrl+c for part
        dispatch(setCopiedPart({ copiedPart: null }));
        dispatch(setCopiedPartActivityId({ copiedPartActivityId: null }));
      }
    },
    ['KeyC'],
    { ctrlKey: true },
    [currentSelectedPartId, _currentPartPropertyFocus],
  );

  const configEditorId = `config-editor-${currentActivityId}`;

  return (
    <React.Fragment>
      <section className={`aa-stage mt-8 ${customInterfaceSettings}`} onClick={handleStageClick}>
        <StagePan>
          {currentActivityTree &&
            currentActivityTree.map((activity) => (
              <AuthoringActivityRenderer
                key={activity.id}
                activityModel={activity as any}
                editMode={activity.id === currentActivityId}
                configEditorId={configEditorId}
                onSelectPart={handlePartSelect}
                onCopyPart={handlePartCopy}
                onConfigurePart={handlePartConfigure}
                onCancelConfigurePart={handlePartCancelConfigure}
                onSaveConfigurePart={handlePartSaveConfigure}
                onPartChangePosition={handlePositionChanged}
                notificationStream={notificationStream}
              />
            ))}
        </StagePan>
      </section>
      <ConfigurationModal
        fullscreen={configModalFullscreen}
        headerText={`Configure: ${configPartId}`}
        bodyId={configEditorId}
        isOpen={showConfigModal}
        customClassName={configModalCustomClassName}
        onClose={() => {
          setShowConfigModal(false);
          setNotificationStream({
            stamp: Date.now(),
            type: NotificationType.CONFIGURE_CANCEL,
            payload: { id: configPartId },
          });
          // after we send the notification we can clear the part id
          setConfigPartId('');
          // also reset fullscreen for the next part
          setConfigModalFullscreen(false);
        }}
        onSave={() => {
          setShowConfigModal(false);
          setNotificationStream({
            stamp: Date.now(),
            type: NotificationType.CONFIGURE_SAVE,
            payload: { id: configPartId }, // no other details are known at this level
          });
          // after we send the notifcation we can clear the part id
          setConfigPartId('');
          // also reset fullscreen for the next part
          setConfigModalFullscreen(false);
        }}
      />
    </React.Fragment>
  );
};

export default EditingCanvas;
