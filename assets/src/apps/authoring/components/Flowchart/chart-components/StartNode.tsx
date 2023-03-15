import React from 'react';
import { Handle, Position } from 'reactflow';

/**
 * This is the empty node on the flowchart that allows you to add new screens to the graph.
 * Eventually it'll be drag and drop, for now it's a button.
 *
 */

interface NodeProps {
  data: any;
}

// Note: use className="nodrag" on interactive pieces here.
export const StartNode: React.FC<NodeProps> = ({ data }) => {
  return (
    <>
      <Handle type="target" position={Position.Left} style={{ display: 'none' }} />
      <StartNodeBody data={data} />
      <Handle type="source" position={Position.Right} id="a" style={{ display: 'none' }} />
    </>
  );
};

// Just the interior of the node, useful to have separate for storybook
export const StartNodeBody: React.FC<NodeProps> = ({ data }) => {
  return (
    <div className="flowchart-start-node">
      <span>Start</span>
    </div>
  );
};
