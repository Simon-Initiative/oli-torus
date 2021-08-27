import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import React, { useCallback } from 'react';
import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel, setRightPanelActiveTab } from '../../store/app/slice';
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

  // TODO: pull from currentActivity with these defaults? (or lesson defaults)
  const width = currentActivity?.content?.custom?.width || 800;
  const height = currentActivity?.content?.custom?.height || 600;

  const background = {
    color: currentActivity?.content?.custom?.palette?.backgroundColor || '#ffffff',
  };

  const layers = (currentActivityTree || []).map((activity) => ({
    id: activity.id,
    parts: activity.content.partsLayout || [],
  }));

  const handleSelectionChanged = (selected: string[]) => {
    const [first] = selected;
    console.log('[handleSelectionChanged]', { selected });
    const newSelection = first || '';
    dispatch(setCurrentSelection({ selection: newSelection }));
    const selectedTab = newSelection ? RightPanelTabs.COMPONENT : RightPanelTabs.SCREEN;
    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: selectedTab }));
  };

  const handlePositionChanged = useCallback(
    async (id: string, deltaX: number, deltaY: number) => {
      console.log('[handlePositionChanged]', { id, deltaX, deltaY });
      if (!currentActivityTree) {
        return;
      }
      // only valid to move on the "owner" layer IF it's current
      const currentActivityClone = clone(currentActivityTree.slice(-1)[0]);
      const partDef = currentActivityClone.content.partsLayout.find((part: any) => part.id === id);
      if (!partDef) {
        return;
      }
      partDef.custom.x += deltaX;
      partDef.custom.y += deltaY;

      dispatch(saveActivity({ activity: currentActivityClone }));
    },
    [currentActivityTree],
  );

  const handlePartSelect = async (id: string) => {
    console.log('[handlePartSelect]', { id });
    dispatch(setCurrentSelection({ selection: id }));

    dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.COMPONENT }));

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

  console.log('EC: RENDER', { layers });

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
              onPartChangePosition={handlePositionChanged}
            />
          ))}
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
