import React, { useCallback } from 'react';
import ReactFlow, { Controls, ReactFlowInstance } from 'reactflow';

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

  const layout = layoutFlowchart(nodes, edges);
  const onInit = useCallback(
    (reactFlowInstance: ReactFlowInstance) => {
      setTimeout(() => {
        const startNode = nodes.filter(
          (n) => (n.data as any)?.authoring?.flowchart?.screenType === 'welcome_screen',
        );
        console.info('Fitting to', startNode);
        reactFlowInstance.fitView({
          nodes: startNode,
        });
      }, 1000);
    },
    [nodes],
  );

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
      <Controls position="top-right" showInteractive={false} />
    </ReactFlow>
  );
};
