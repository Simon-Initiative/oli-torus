/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { EntityId } from '@reduxjs/toolkit';
import React, { useCallback, useMemo } from 'react';
import { ListGroup, ListGroupItem } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useToggle } from '../../../../components/hooks/useToggle';
import { useOnClickOutside } from '../../../../hooks/click_outside';
import {
  selectAllActivities,
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import { AdvancedAuthoringPopup } from '../AdvancedAuthoringModal';
import { addFlowchartScreen } from '../Flowchart/flowchart-actions/add-screen';
import { deleteFlowchartScreen } from '../Flowchart/flowchart-actions/delete-screen';
import { duplicateFlowchartScreen } from '../Flowchart/flowchart-actions/duplicate-screen';
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

interface ContextProps {
  position: [number, number];
  onDelete: () => void;
  onDuplicate: () => void;
  onCancel: () => void;
}

const ContextMenu: React.FC<ContextProps> = ({ position, onDelete, onDuplicate, onCancel }) => {
  const ref = useOnClickOutside<HTMLDivElement>(onCancel);
  return (
    <ListGroup
      ref={ref}
      style={{
        zIndex: 1000,
        position: 'fixed',
        top: position[1],
        left: position[0],
      }}
    >
      <ListGroupItem action onClick={onDuplicate}>
        Duplicate Screen
      </ListGroupItem>
      <ListGroupItem action onClick={onDelete}>
        Delete Screen
      </ListGroupItem>
    </ListGroup>
  );
};

export const ScreenList: React.FC<Props> = ({ onFlowchartMode }) => {
  const dispatch = useDispatch();
  const activities = useSelector(selectAllActivities);
  const currentActivityId = useSelector(selectCurrentActivityId);
  const [showNewScreenModal, , openNewScreenModal, closeNewScreenModal] = useToggle(false);
  const [contextMenuCoordinates, setContextMenuCoordinates] = React.useState<
    [number, number] | null
  >(null);
  const [contextMenuScreenId, setContextMenuScreenId] = React.useState<number | null>(null);

  const sequence = useSelector(selectSequence);

  const sortedActivities = useMemo(() => sortScreens(activities, sequence), [activities, sequence]);

  const isEndScreen = useCallback(
    (resourceId: EntityId) => {
      return (
        activities.find((s) => s.resourceId === resourceId)?.authoring?.flowchart?.screenType ===
        'end_screen'
      );
    },
    [activities],
  );

  const onAddNewScreen = useCallback(() => {
    openNewScreenModal();
  }, [openNewScreenModal]);

  const onCreate = useCallback(
    (title: string, screenType: ScreenTypes) => {
      closeNewScreenModal();
      dispatch(
        addFlowchartScreen({
          title,
          screenType,
        }),
      );
    },
    [closeNewScreenModal, dispatch],
  );

  const onSelectScreen = useCallback(
    (screenResourceId: EntityId) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
    },
    [dispatch],
  );

  const onDeleteScreen = useCallback(() => {
    if (contextMenuScreenId === null) return;
    dispatch(deleteFlowchartScreen({ screenId: contextMenuScreenId }));
    console.info('Delete screen', contextMenuScreenId);
  }, [contextMenuScreenId, dispatch]);

  const onDuplicateScreen = useCallback(() => {
    if (contextMenuScreenId === null) return;
    dispatch(duplicateFlowchartScreen({ screenId: contextMenuScreenId }));

    console.info('Duplicate screen', contextMenuScreenId);
  }, [contextMenuScreenId, dispatch]);

  const onScreenRightClick = useCallback(
    (screenId: number) => (e: any) => {
      if (isEndScreen(screenId)) return;
      const { clientX, clientY } = e;
      e.preventDefault();
      setContextMenuScreenId(screenId);
      setContextMenuCoordinates([clientX, clientY]);
    },
    [isEndScreen],
  );

  return (
    <div>
      {contextMenuCoordinates && (
        <AdvancedAuthoringPopup>
          <ContextMenu
            position={contextMenuCoordinates}
            onDelete={onDeleteScreen}
            onDuplicate={onDuplicateScreen}
            onCancel={() => setContextMenuCoordinates(null)}
          />
        </AdvancedAuthoringPopup>
      )}
      {showNewScreenModal && <AddScreenModal onCancel={closeNewScreenModal} onCreate={onCreate} />}
      <FlowchartModeOptions onFlowchartMode={onFlowchartMode} onAddNewScreen={onAddNewScreen} />
      <ul className="screen-list">
        {sortedActivities.map((activity) => (
          <li
            className={currentActivityId === activity.id ? 'active' : ''}
            key={activity.id}
            onClick={() => onSelectScreen(activity.resourceId!)}
            onContextMenu={onScreenRightClick(activity.resourceId!)}
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
