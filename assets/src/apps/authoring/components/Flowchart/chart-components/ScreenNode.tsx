import React, { useContext } from 'react';
import { useSelector } from 'react-redux';
import { Handle, Position } from 'reactflow';
import { Icon } from '../../../../../components/misc/Icon';
import {
  IActivity,
  selectCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';

import { FlowchartEventContext } from '../FlowchartEventContext';
import { ScreenButton } from './ScreenButton';

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
  const selectedId = useSelector(selectCurrentActivityId);
  const selected = selectedId === data.resourceId;
  const className = `node-box ${selected ? 'node-selected' : ''}`;

  return (
    <div className="flowchart-node">
      <div className="inline text-center">{data.title}</div>
      <div className={className} onClick={() => onSelectScreen(data.resourceId!)}>
        <div className="button-bar">
          <ScreenButton onClick={() => onAddScreen({ prevNodeId: data.resourceId })}>
            <Icon icon="plus" />
          </ScreenButton>

          <ScreenButton onClick={() => onEditScreen(data.resourceId!)}>
            <Icon icon="edit" />
          </ScreenButton>
          {/* <ScreenButton onClick={dontDoNothing}>
            <Icon icon="clone" />
          </ScreenButton> */}
          <ScreenButton onClick={() => onDeleteScreen(data.resourceId!)}>
            <Icon icon="trash" />
          </ScreenButton>
        </div>
      </div>
      <small className="text-gray-400">{data.resourceId}</small>
    </div>
  );
};
