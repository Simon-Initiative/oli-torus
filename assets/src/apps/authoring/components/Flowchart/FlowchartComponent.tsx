import React from 'react';
import ReactFlow, { Controls, Background } from 'reactflow';

import { layoutFlowchart } from './flowchart-layout';

import { FlowchartEdge, FlowchartNode } from './flowchart-utils';
import { ScreenNode } from './chart-components/ScreenNode';
import { FloatingEdge } from './chart-components/FloatingEdge';
import FloatingConnectionLine from './chart-components/FloatingConnectionLine';
import { EndNode } from './chart-components/PlaceholderNode';
import { PlaceholderEdge } from './chart-components/PlaceholderEdge';
import { StartNode } from './chart-components/StartNode';

interface FlowchartComponentProps {
  nodes: FlowchartNode[];
  edges: FlowchartEdge[];
}

const NodeTypes = {
  screen: ScreenNode,
  placeholder: EndNode,
  start: StartNode,
};

const EdgeTypes = {
  floating: FloatingEdge,
  placeholder: PlaceholderEdge,
};

export const FlowchartComponent: React.FC<FlowchartComponentProps> = (props) => {
  const { nodes, edges } = props;

  // if (nodes.length > 1) {
  //   debugger;
  // }

  const layout = layoutFlowchart(nodes, edges);
  // TODO - we're currently ignoring the dagre edges from layout. I think we could avoid some overlaps by using them.

  return (
    <ReactFlow
      nodeTypes={NodeTypes}
      edgeTypes={EdgeTypes}
      nodes={layout.nodes}
      edges={layout.edges}
      panOnDrag={true}
      nodesDraggable={false}
      nodesConnectable={false}
      connectionLineComponent={FloatingConnectionLine}
      proOptions={{ hideAttribution: true }}
    >
      {/* <MiniMap /> */}
      <Controls />
      <Background />
    </ReactFlow>
  );
};
