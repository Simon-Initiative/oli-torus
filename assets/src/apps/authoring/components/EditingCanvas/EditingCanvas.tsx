import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { NotificationType } from 'apps/delivery/components/NotificationContext';
import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel, setCopiedPart, setRightPanelActiveTab } from '../../store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from '../../store/parts/slice';
import { RightPanelTabs } from '../RightMenu/RightMenu';
import AuthoringActivityRenderer from './AuthoringActivityRenderer';
import ConfigurationModal from './ConfigurationModal';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentPartSelection = useSelector(selectCurrentSelection);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const [currentActivityId, setCurrentActivityId] = useState<string>('');

  const [showConfigModal, setShowConfigModal] = useState<boolean>(false);
  const [configModalFullscreen, setConfigModalFullscreen] = useState<boolean>(false);
  const [configPartId, setConfigPartId] = useState<string>('');

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

  const handleSelectionChanged = (selected: string[]) => {
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

    dispatch(updatePart({ activityId, partId, changes: { custom: newPosition } }));

    return newPosition;
  };

  const handlePartSelect = async (id: string) => {
    /* console.log('[handlePartSelect]', { id }); */
    dispatch(setCurrentSelection({ selection: id }));

    dispatch(
      setRightPanelActiveTab({
        rightPanelActiveTab: !id.length ? RightPanelTabs.SCREEN : RightPanelTabs.COMPONENT,
      }),
    );

    return true;
  };

  const handlePartCopy = async (part: any) => {
    dispatch(setCopiedPart({ copiedPart: part }));
    return true;
  };

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
    const { fullscreen = false } = context;
    setConfigModalFullscreen(fullscreen);
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
  };

  // console.log('EC: RENDER', { layers });

  useEffect(() => {
    dispatch(setCurrentSelection({ selection: '' }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  }, [currentActivityId]);

  const configEditorId = `config-editor-${currentActivityId}`;

  return (
    <React.Fragment>
      <section className="aa-stage" onClick={handleStageClick}>
        {currentActivityTree &&
          currentActivityTree.map((activity) => (
            <AuthoringActivityRenderer
              key={activity.id}
              activityModel={activity}
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
      </section>
      <ConfigurationModal
        fullscreen={configModalFullscreen}
        headerText={`Configure: ${configPartId}`}
        bodyId={configEditorId}
        isOpen={showConfigModal}
        onClose={() => {
          setShowConfigModal(false);
          setNotificationStream({
            stamp: Date.now(),
            type: NotificationType.CONFIGURE_CANCEL,
            payload: { id: configPartId },
          });
          // after we send the notifcation we can clear the part id
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
