import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import React, { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel, setCopiedPart, setRightPanelActiveTab } from '../../store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from '../../store/parts/slice';
import { RightPanelTabs } from '../RightMenu/RightMenu';
import AuthoringActivityRenderer from './AuthoringActivityRenderer';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentPartSelection = useSelector(selectCurrentSelection);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  const [currentActivityId, setCurrentActivityId] = React.useState<string>('');

  useEffect(() => {
    let current = null;
    if (currentActivityTree) {
      current = currentActivityTree.slice(-1)[0];
    }
    setCurrentActivityId(current?.id || '');
  }, [currentActivityTree]);

  const handleSelectionChanged = (selected: string[]) => {
    const [first] = selected;
    console.log('[handleSelectionChanged]', { selected });
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

    console.log('[handlePositionChanged]', { activityId, partId, dragData });

    const newPosition = { x: dragData.x, y: dragData.y };

    dispatch(updatePart({ activityId, partId, changes: { custom: newPosition } }));

    return newPosition;
  };

  const handlePartSelect = async (id: string) => {
    console.log('[handlePartSelect]', { id });
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
    console.log('[handleStageClick]', e);
    dispatch(setCurrentSelection({ selection: '' }));

    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  };

  // console.log('EC: RENDER', { layers });

  useEffect(() => {
    dispatch(setCurrentSelection({ selection: '' }));
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
  }, [currentActivityId]);

  return (
    <React.Fragment>
      <section className="aa-stage" onClick={handleStageClick}>
        {currentActivityTree &&
          currentActivityTree.map((activity) => (
            <AuthoringActivityRenderer
              key={activity.id}
              activityModel={activity}
              editMode={activity.id === currentActivityId}
              onSelectPart={handlePartSelect}
              onCopyPart={handlePartCopy}
              onPartChangePosition={handlePositionChanged}
            />
          ))}
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
