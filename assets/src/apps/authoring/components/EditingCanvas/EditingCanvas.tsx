import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../delivery/store/features/groups/selectors/deck';
import { selectBottomPanel, setRightPanelActiveTab } from '../../store/app/slice';
import { RightPanelTabs } from '../RightMenu/RightMenu';
import FabricCanvas from './FabricCanvas';

const EditingCanvas: React.FC = () => {
  const dispatch = useDispatch();
  const bottomPanelState = useSelector(selectBottomPanel);
  const currentActivityTree = useSelector(selectCurrentActivityTree);

  const [currentActivity] = (currentActivityTree || []).slice(-1);

  // TODO: pull from currentActivity with these defaults? (or lesson defaults)
  const width = currentActivity?.content?.custom?.width || 800;
  const height = currentActivity?.content?.custom?.height || 600;

  const items =
    currentActivityTree?.reduce((acc, activity) => {
      // TODO: map these items to a new object that has a few more things
      // such as layer items should be readonly
      return acc.concat(...activity.content.partsLayout);
    }, []) || [];

  return (
    <React.Fragment>
      <section
        className="aa-stage"
        onClick={(e) => {
          dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.LESSON }));
        }}
      >
        <div
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
          <FabricCanvas items={items} width={width} height={height} />
        </div>
      </section>
    </React.Fragment>
  );
};

export default EditingCanvas;
