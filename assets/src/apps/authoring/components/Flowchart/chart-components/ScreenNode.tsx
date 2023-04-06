import React, { useCallback, useContext } from 'react';
import { OverlayTrigger, Tooltip, Dropdown } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { useDrop } from 'react-dnd';
import { Handle, Position } from 'reactflow';
import { Icon } from '../../../../../components/misc/Icon';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';

import { FlowchartEventContext } from '../FlowchartEventContext';
import { screenTypes } from '../screens/screen-factories';
import { ScreenButton } from './ScreenButton';
import ConfirmDelete from '../../Modal/DeleteConfirmationModal';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { validateScreen } from '../screens/screen-validation';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { duplicateFlowchartScreen } from '../flowchart-actions/duplicate-screen';

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

const dontDoNothing = () => {
  console.warn("This don't do nuthin yet");
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
      onAddScreen({ nextNodeId: data.resourceId, screenType: item.screenType });
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

  const validity = isValid ? 'node-valid' : 'node-invalid';

  return (
    <div className={`flowchart-node ${validity}`}>
      <div className="title-bar">
        <div className="title-icon">
          <Icon icon="page" />
        </div>
        <div className="inline text-center">{data.title}</div>
      </div>

      <div
        className={classNames.join(' ')}
        onClick={() => onSelectScreen(data.resourceId!)}
        ref={drop}
      >
        <div className="button-bar">
          {/* <ScreenButton onClick={() => onAddScreen({ prevNodeId: data.resourceId })}>
            <Icon icon="plus" />
          </ScreenButton> */}

          <ScreenButton tooltip="Edit Screen" onClick={() => onEditScreen(data.resourceId!)}>
            <Icon icon="edit" />
          </ScreenButton>
          {isRequiredScreen || (
            <>
              <ScreenButton tooltip="Duplicate Screen" onClick={onDuplicateScreen}>
                <Icon icon="clone" />
              </ScreenButton>
              <ScreenButton tooltip="Delete Screen" onClick={toggleConfirmDelete}>
                <Icon icon="trash" />
              </ScreenButton>
            </>
          )}
        </div>
      </div>
      <small className="text-gray-400">{data.resourceId}</small>

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
