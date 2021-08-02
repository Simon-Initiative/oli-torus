import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel } from '../../store/app/slice';
import { selectCurrentSelection, setCurrentSelection } from '../../store/parts/slice';
import KonvaStage from './KonvaStage';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentPartSelection = useSelector(selectCurrentSelection);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

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
    dispatch(setCurrentSelection({ selection: first || '' }));
  };
  console.log('EC: RENDER', { layers });

  return (
    <React.Fragment>
      <section className="aa-stage">
        {currentActivity && (
          <KonvaStage
            key={currentActivity.id}
            selected={[currentPartSelection]}
            background={background}
            size={{ width, height }}
            layers={layers}
            onSelectionChange={handleSelectionChanged}
          />
        )}
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
