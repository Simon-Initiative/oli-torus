import { EntityId } from '@reduxjs/toolkit';
import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectAllActivities,
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import { FlowchartModeOptions } from '../Flowchart/FlowchartModeOptions';

/*
  The ScreenList is a simplified view of activities within a lesson similar to the SequenceEditor, but with a reduced feature set
  and only respects simple lessons authored via the flowchart flow.
*/

interface Props {
  onFlowchartMode?: () => void;
}

export const ScreenList: React.FC<Props> = ({ onFlowchartMode }) => {
  const dispatch = useDispatch();
  const activities = useSelector(selectAllActivities);
  const currentActivityId = useSelector(selectCurrentActivityId);

  const onSelectScreen = useCallback(
    (screenResourceId: EntityId) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
    },
    [dispatch],
  );

  return (
    <div>
      <FlowchartModeOptions onFlowchartMode={onFlowchartMode} />
      <ul className="screen-list">
        {activities.map((activity) => (
          <li
            className={currentActivityId === activity.id ? 'active' : ''}
            key={activity.id}
            onClick={() => onSelectScreen(activity.resourceId!)}
          >
            <div className="page-icon">
              <span>?</span>
            </div>
            {activity.title || 'untitled screen'}
          </li>
        ))}
      </ul>
    </div>
  );
};
