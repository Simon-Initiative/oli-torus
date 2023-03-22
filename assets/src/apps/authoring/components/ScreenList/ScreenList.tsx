import { EntityId } from '@reduxjs/toolkit';
import React, { useCallback, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useToggle } from '../../../../components/hooks/useToggle';
import {
  selectAllActivities,
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import { addFlowchartScreen } from '../Flowchart/flowchart-actions/add-screen';
import { FlowchartModeOptions } from '../Flowchart/FlowchartModeOptions';
import { ScreenTypes } from '../Flowchart/screens/screen-factories';
import { sortScreens } from '../Flowchart/screens/screen-utils';
import { AddScreenModal } from './AddScreenModal';

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
  const [showNewScreenModal, , openModal, closeModal] = useToggle(false);
  const sequence = useSelector(selectSequence);

  const sortedActivities = useMemo(() => sortScreens(activities, sequence), [activities]);

  const onAddNewScreen = useCallback(() => {
    openModal();
  }, [openModal]);
  const onCreate = useCallback(
    (title: string, screenType: ScreenTypes) => {
      closeModal();
      dispatch(
        addFlowchartScreen({
          title,
          screenType,
        }),
      );
    },
    [closeModal, dispatch],
  );

  const onSelectScreen = useCallback(
    (screenResourceId: EntityId) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
    },
    [dispatch],
  );

  return (
    <div>
      {showNewScreenModal && <AddScreenModal onCancel={closeModal} onCreate={onCreate} />}
      <FlowchartModeOptions onFlowchartMode={onFlowchartMode} onAddNewScreen={onAddNewScreen} />
      <ul className="screen-list">
        {sortedActivities.map((activity) => (
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
