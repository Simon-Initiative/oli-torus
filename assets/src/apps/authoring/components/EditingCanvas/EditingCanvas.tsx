import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel, setRightPanelActiveTab } from '../../store/app/slice';
import { setCurrentSelection } from '../../store/parts/slice';
import { RightPanelTabs } from '../RightMenu/RightMenu';
import KonvaStage from './KonvaStage';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);

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

  const handleObjectClicked = (e: any, item: any) => {
    console.log('object clicked handler', { e, item });
    dispatch(setCurrentSelection({ selection: item.id }));
  };
  console.log('EC: RENDER', { layers });

  return (
    <React.Fragment>
      <section
        className="aa-stage"
        onClick={(e) => {
          dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.LESSON }));
        }}
      >
        <KonvaStage background={background} size={{ width, height }} layers={layers} />
        {/* <div
          className="aa-stage-inner"
          style={{
            width,
            height,
            marginBottom: bottomPanelState ? 'calc(40vh + 64px)' : 'calc(64px + 39px)',
          }}
          onClick={(e) => {
            e.stopPropagation();
            dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
          }}
        >
          {false && <KonvaStage />}
        </div> */}
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
