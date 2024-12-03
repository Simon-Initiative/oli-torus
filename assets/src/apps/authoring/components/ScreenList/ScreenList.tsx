/* eslint-disable @typescript-eslint/no-non-null-assertion */
import React, { useCallback, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { EntityId } from '@reduxjs/toolkit';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { useClickOutside } from '../../../../components/hooks/useClickOutside';
import { useToggle } from '../../../../components/hooks/useToggle';
import {
  selectAllActivities,
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import { AdvancedAuthoringPopup } from '../AdvancedAuthoringModal';
import { FlowchartModeOptions } from '../Flowchart/FlowchartModeOptions';
import { addFlowchartScreen } from '../Flowchart/flowchart-actions/add-screen';
import { deleteFlowchartScreen } from '../Flowchart/flowchart-actions/delete-screen';
import { duplicateFlowchartScreen } from '../Flowchart/flowchart-actions/duplicate-screen';
import { BlankScreenIcon } from '../Flowchart/screen-icons/BlankScreenIcon';
import { ScreenValidationColors, screenTypeToIcon } from '../Flowchart/screen-icons/screen-icons';
import { ScreenTypes } from '../Flowchart/screens/screen-factories';
import { getFirstScreenInSequence, sortScreens } from '../Flowchart/screens/screen-utils';
import { InfoIcon } from '../Flowchart/sidebar/InfoIcon';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
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
  const ref = useClickOutside<HTMLUListElement>(onCancel);
  return (
    <ul
      className="screen-context-menu"
      ref={ref}
      style={{
        zIndex: 1000,
        position: 'fixed',
        top: position[1],
        left: position[0],
      }}
    >
      <li onClick={onDuplicate}>Duplicate Screen</li>
      <li onClick={onDelete}>Delete Screen</li>
    </ul>
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
  const [confirmDeleteScreenId, setConfirmDeleteScreenId] = React.useState<number | null>(null);

  const sequence = useSelector(selectSequence);

  const sortedActivities = useMemo(() => {
    const firstScreen = getFirstScreenInSequence(activities, sequence);
    return sortScreens(activities, firstScreen);
  }, [activities, sequence]);

  const isEndScreen = useCallback(
    (resourceId: EntityId) => {
      return (
        activities.find((s) => s.resourceId === resourceId)?.authoring?.flowchart?.screenType ===
        'end_screen'
      );
    },
    [activities],
  );

  const isStartScreen = useCallback(
    (resourceId: EntityId) => {
      return (
        activities.find((s) => s.resourceId === resourceId)?.authoring?.flowchart?.screenType ===
        'welcome_screen'
      );
    },
    [activities],
  );

  const onAddNewScreen = useCallback(() => {
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
    openNewScreenModal();
  }, [openNewScreenModal]);

  const onCreate = useCallback(
    (title: string, screenType: ScreenTypes) => {
      closeNewScreenModal();
      dispatch(setCurrentPartPropertyFocus({ focus: true }));
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
      dispatch(setCurrentPartPropertyFocus({ focus: false }));
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
    },
    [dispatch],
  );

  const onConfirmDeleteScreen = useCallback(() => {
    if (confirmDeleteScreenId === null) return;
    dispatch(deleteFlowchartScreen({ screenId: confirmDeleteScreenId }));
    setConfirmDeleteScreenId(null);
  }, [confirmDeleteScreenId, dispatch]);

  const onDeleteScreen = useCallback(() => {
    if (contextMenuScreenId === null) return;
    setConfirmDeleteScreenId(contextMenuScreenId);
    setContextMenuScreenId(null);
  }, [contextMenuScreenId, dispatch]);

  const onDuplicateScreen = useCallback(() => {
    if (contextMenuScreenId === null) return;
    dispatch(duplicateFlowchartScreen({ screenId: contextMenuScreenId }));

    console.info('Duplicate screen', contextMenuScreenId);
    setContextMenuScreenId(null);
  }, [contextMenuScreenId, dispatch]);

  const onScreenRightClick = useCallback(
    (screenId: number) => (e: any) => {
      if (isEndScreen(screenId)) return;
      if (isStartScreen(screenId)) return;
      const { clientX, clientY } = e;
      e.preventDefault();
      setContextMenuScreenId(screenId);
      setContextMenuCoordinates([clientX, clientY]);
    },
    [isEndScreen, isStartScreen],
  );

  return (
    <div className="screen-list-container">
      {confirmDeleteScreenId && (
        <ConfirmDelete
          show={true}
          elementType="screen"
          title="Are you sure you want to delete this screen?"
          explanation="Please note, you will permanently lose all content on this screen, and you will unable to undo this action. Consider creating a duplicate of your screen before proceeding."
          deleteHandler={onConfirmDeleteScreen}
          cancelHandler={() => setConfirmDeleteScreenId(null)}
        />
      )}
      {contextMenuCoordinates && contextMenuScreenId && (
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
      <FlowchartModeOptions
        onFlowchartMode={onFlowchartMode}
        onAddNewScreen={onAddNewScreen}
        activeMode="page"
        reverseOrder={true}
      />

      <div className="screenlist-scroller">
        <div className="flowchart-order-note">
          <InfoIcon />
          <div>
            If you want to change the order of the screens, please go to the{' '}
            <a onClick={onFlowchartMode}>flowchart</a>
          </div>
        </div>

        <ul className="screen-list">
          {sortedActivities.map((activity) => (
            <li
              className={currentActivityId === activity.id ? 'active' : ''}
              key={activity.id}
              onClick={() => onSelectScreen(activity.resourceId!)}
              onContextMenu={onScreenRightClick(activity.resourceId!)}
            >
              <ScreenIcon
                fill={ScreenValidationColors.VALIDATED}
                screenType={activity.authoring?.flowchart?.screenType || 'blank_screen'}
              />
              {activity.title || 'untitled screen'}
            </li>
          ))}
        </ul>
      </div>
      <button onClick={onAddNewScreen} className="btn btn-primary flowchart-sidebar-button m-4">
        Add new screen
      </button>
    </div>
  );
};

const ScreenIcon: React.FC<{ screenType: string; fill: string }> = ({ screenType, fill }) => {
  const Icon = screenTypeToIcon[screenType] || BlankScreenIcon;
  return <Icon fill={fill} />;
};
