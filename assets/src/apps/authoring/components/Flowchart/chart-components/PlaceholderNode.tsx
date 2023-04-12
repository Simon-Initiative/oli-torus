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
export const EndNode: React.FC<NodeProps> = ({ data }) => {
  return (
    <>
      <Handle type="target" position={Position.Left} style={{ display: 'none' }} />
      <EndNodeBody />
      <Handle type="source" position={Position.Right} id="a" style={{ display: 'none' }} />
    </>
  );
};

// Just the interior of the node, useful to have separate for storybook
export const EndNodeBody: React.FC = () => {
  return (
    <div className="flowchart-end-node">
      <span>End</span>
    </div>
  );
};
