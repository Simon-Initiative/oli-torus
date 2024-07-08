import React, { useMemo } from 'react';
import ReactFlow, { Controls } from 'reactflow';
import FloatingConnectionLine from './chart-components/FloatingConnectionLine';
import { FloatingEdge } from './chart-components/FloatingEdge';
import { PlaceholderEdge } from './chart-components/PlaceholderEdge';
import { EndNode } from './chart-components/PlaceholderNode';
import { ScreenNode } from './chart-components/ScreenNode';
import { StartNode } from './chart-components/StartNode';
import { layoutFlowchart } from './flowchart-layout';
import { FlowchartEdge, FlowchartNode } from './flowchart-utils';

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
  const layout = useMemo(() => layoutFlowchart(nodes, edges), [nodes, edges]);
  // const onInit = useCallback(
  //   (reactFlowInstance: ReactFlowInstance) => {
  //     setTimeout(() => {
  //       const startNode = nodes.filter(
  //         (n) => (n.data as any)?.authoring?.flowchart?.screenType === 'welcome_screen',
  //       );
  //       console.info('Fitting to', startNode);
  //       reactFlowInstance.fitView({
  //         nodes: startNode,
  //       });
  //     }, 1000);
  //   },
  //   [nodes],
  // );

  return useMemo(
    () => (
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
    ),
    [layout.nodes, layout.edges],
  );
};
