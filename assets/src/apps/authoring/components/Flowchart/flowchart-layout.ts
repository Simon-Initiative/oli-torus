import { FlowchartEdge, FlowchartNode } from './flowchart-utils';
import dagre from 'dagre';

export const BOX_WIDTH = 150;
export const BOX_HEIGHT = 155;

const dagreEdgeToFlowchartEdge = (edge: FlowchartEdge & dagre.GraphEdge): FlowchartEdge => {
  const { points, ...rest } = edge;

  return {
    ...rest,
    data: {
      ...edge.data,
      points,
    },
  };
};

export const layoutFlowchart = (nodes: FlowchartNode[], edges: FlowchartEdge[]) => {
  const g = new dagre.graphlib.Graph<FlowchartNode>();

  console.info('layoutFlowchart', nodes.length, edges.length, edges);

  // const nonCycleEdges = weightCycles(edges);

  // Set an object for the graph label
  g.setGraph({
    rankdir: 'LR',
    // align: 'UL',
    // marginx: 50,
    // marginy: 50,
    ranker: 'tight-tree',
    nodesep: BOX_HEIGHT,
    // acyclicer: 'greedy',
    ranksep: BOX_HEIGHT,
  });

  // Default to assigning a new object as a label for each new edge.
  g.setDefaultEdgeLabel(function () {
    return {};
  });

  // Add nodes to the graph. The first argument is the node id. The second is
  // metadata about the node. In this case we're going to add labels to each of
  // our nodes.
  nodes.forEach((node) => {
    g.setNode(node.id, {
      ...node,
      // label: node.data.label,
      width: BOX_WIDTH,
      height: BOX_HEIGHT,
    });
  });

  edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target, edge);
  });

  dagre.layout(g);

  return {
    nodes: g
      .nodes()
      .filter((id) => !!g.node(id))
      .map((id) => {
        const node = g.node(id);
        return {
          id: node.id,
          position: { x: node.x, y: node.y },
          data: node.data,
          type: node.type,
        };
      }),

    edges: g
      .edges()
      .map((edge) => g.edge(edge))
      .map(dagreEdgeToFlowchartEdge),
  };
};
