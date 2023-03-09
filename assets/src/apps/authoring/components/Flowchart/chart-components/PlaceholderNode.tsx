import React, { useContext } from 'react';
import { useDrop } from 'react-dnd';
import { Handle, Position } from 'reactflow';
import { FlowchartPlaceholderNodeData } from '../flowchart-utils';
import { FlowchartEventContext } from '../FlowchartEventContext';
import { screenTypes } from '../screens/screen-factories';

/**
 * This is the empty node on the flowchart that allows you to add new screens to the graph.
 * Eventually it'll be drag and drop, for now it's a button.
 *
 */

interface NodeProps {
  data: FlowchartPlaceholderNodeData;
}

// Note: use className="nodrag" on interactive pieces here.
export const PlaceholderNode: React.FC<NodeProps> = ({ data }) => {
  return (
    <>
      <Handle type="target" position={Position.Left} style={{ display: 'none' }} />
      <PlaceholderNodeBody data={data} />
      <Handle type="source" position={Position.Right} id="a" style={{ display: 'none' }} />
    </>
  );
};

// Just the interior of the node, useful to have separate for storybook
export const PlaceholderNodeBody: React.FC<NodeProps> = ({ data }) => {
  const { onAddScreen } = useContext(FlowchartEventContext);

  const onDrop = (item: any) => {
    onAddScreen({ prevNodeId: data.fromScreenId, screenType: item.screenType });
  };

  const [{ canDrop, isOver }, drop] = useDrop(() => ({
    accept: screenTypes,
    drop: onDrop,
    collect: (monitor) => ({
      isOver: monitor.isOver(),
      canDrop: monitor.canDrop(),
    }),
  }));

  const hover = isOver && canDrop;
  const className = hover ? 'node-box drop-over placeholder' : 'node-box placeholder';

  return (
    <div className="flowchart-node">
      <div className={className} ref={drop}>
        {hover && <DropMessage />}
        {hover || (
          <button
            className="flowchart-button"
            onClick={() => onAddScreen({ prevNodeId: data.fromScreenId })}
          >
            Add Screen
          </button>
        )}
      </div>
    </div>
  );
};

const DropMessage: React.FC = () => <span>Drop here to add new screen</span>;
