/* eslint-disable @typescript-eslint/no-non-null-assertion */
import React, { useCallback, useContext } from 'react';
import { useDrop } from 'react-dnd';
import { useDispatch, useSelector } from 'react-redux';
import { Handle, Position } from 'reactflow';
import { useToggle } from '../../../../../components/hooks/useToggle';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import ConfirmDelete from '../../Modal/DeleteConfirmationModal';
import { FlowchartEventContext } from '../FlowchartEventContext';
import { duplicateFlowchartScreen } from '../flowchart-actions/duplicate-screen';
import { ScreenValidationColors } from '../screen-icons/screen-icons';
import { screenTypes } from '../screens/screen-factories';
import { validateScreen } from '../screens/screen-validation';
import { ScreenButton } from './ScreenButton';
import { ScreenDeleteIcon } from './ScreenDeleteIcon';
import { ScreenDuplicateIcon } from './ScreenDuplicateIcon';
import { ScreenEditIcon } from './ScreenEditIcon';
import { ScreenIcon } from './ScreenIcon';

interface NodeProps {
  data: IActivity;
}

// Note: use className="nodrag" on interactive pieces here.
export const ScreenNode: React.FC<NodeProps> = ({ data }) => {
  return (
    <>
      <Handle type="target" position={Position.Left} style={{ display: 'none' }} />
      <ScreenNodeBody data={data} />
      <Handle type="source" position={Position.Right} id="a" style={{ display: 'none' }} />
    </>
  );
};

// Just the interior of the node, useful to have separate for storybook
export const ScreenNodeBody: React.FC<NodeProps> = ({ data }) => {
  const { onAddScreen, onDeleteScreen, onSelectScreen, onEditScreen } =
    useContext(FlowchartEventContext);
  const dispatch = useDispatch();
  const selectedId = useSelector(selectCurrentActivityId);
  const selected = selectedId === data.resourceId;
  const [showConfirmDelete, toggleConfirmDelete] = useToggle(false);

  const activities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);

  const isValid = validateScreen(data, activities, sequence).length === 0;
  const isEndScreen =
    activities.find((s) => s.resourceId === data.resourceId)?.authoring?.flowchart?.screenType ===
    'end_screen';
  const isWelcomeScreen =
    activities.find((s) => s.resourceId === data.resourceId)?.authoring?.flowchart?.screenType ===
    'welcome_screen';

  const isRequiredScreen = isEndScreen || isWelcomeScreen;

  const onDrop = (item: any) => {
    if (isEndScreen) {
      console.warn("Can't add a screen after the end screen");
    } else {
      onAddScreen({ prevNodeId: data.resourceId, screenType: item.screenType });
    }
  };

  const onDuplicateScreen = useCallback(() => {
    if (!data.resourceId) return;
    dispatch(duplicateFlowchartScreen({ screenId: data.resourceId }));
  }, [data.resourceId, dispatch]);

  const [{ canDrop, isOver }, drop] = useDrop(() => ({
    accept: screenTypes,
    canDrop: () => !isEndScreen,
    drop: onDrop,
    collect: (monitor) => ({
      isOver: monitor.isOver(),
      canDrop: monitor.canDrop(),
    }),
  }));

  const hover = isOver && canDrop;

  const classNames = ['node-box'];
  if (selected) classNames.push('node-selected');
  if (hover) classNames.push('drop-over');

  const iconBG = isValid ? ScreenValidationColors.VALIDATED : ScreenValidationColors.NOT_VALIDATED;

  return (
    <div className={`flowchart-node`}>
      <div className="title-bar">
        <div className="title-icon">
          <ScreenIcon screenType={data.authoring?.flowchart?.screenType} bgColor={iconBG} />
        </div>
        <div className="title-text" title={data.title}>
          {data.title}
        </div>
      </div>

      <div
        className={classNames.join(' ')}
        onClick={() => onSelectScreen(data.resourceId!)}
        ref={drop}
      >
        <div className="button-bar">
          {isWelcomeScreen && <span className="start-end-label">Start</span>}
          {isEndScreen && <span className="start-end-label">End</span>}

          {selected && (
            <>
              <ScreenButton tooltip="Edit Screen" onClick={() => onEditScreen(data.resourceId!)}>
                <ScreenEditIcon />
              </ScreenButton>
              {isRequiredScreen || (
                <>
                  <ScreenButton tooltip="Duplicate Screen" onClick={onDuplicateScreen}>
                    <ScreenDuplicateIcon />
                  </ScreenButton>
                  <ScreenButton tooltip="Delete Screen" onClick={toggleConfirmDelete}>
                    <ScreenDeleteIcon />
                  </ScreenButton>
                </>
              )}
            </>
          )}
        </div>
      </div>
      {isValid || <small className="text-gray-400">This screen is not validated.</small>}

      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Screen"
          elementName={data.title}
          deleteHandler={() => {
            onDeleteScreen(data.resourceId!);
            toggleConfirmDelete();
          }}
          cancelHandler={toggleConfirmDelete}
        />
      )}
    </div>
  );
};
