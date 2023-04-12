/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { MarkerType } from 'reactflow';
import guid from '../../../../utils/guid';
import { IActivity } from '../../../delivery/store/features/activities/slice';
import { AllPaths } from './paths/path-types';
import { buildEdgesForActivity, isEndOfActivityPath, isExitActivityPath } from './paths/path-utils';

export interface FlowchartPlaceholderNodeData {
  fromScreenId: number;
}

export interface FlowchartScreenNode {
  id: string;
  resourceId: number;
  position: { x: number; y: number };
  data: IActivity;
  type: 'screen';
  draggable: false;
}

interface FlowchartStartNodeData {
  toScreenId: number;
}

export interface FlowchartStartNode {
  id: string;
  position: { x: number; y: number };
  data: FlowchartStartNodeData;
  type: 'start';
  draggable: false;
}

export interface FlowchartPlaceholderNode {
  id: string;
  position: { x: number; y: number };
  data: FlowchartPlaceholderNodeData;
  type: 'placeholder';
  draggable: false;
}

export type FlowchartNode = FlowchartScreenNode | FlowchartPlaceholderNode | FlowchartStartNode;

export interface Point {
  x: number;
  y: number;
}

export interface FlowchartEdgeData {
  points?: Point[];
  completed: boolean;
}

export interface FlowchartEdge {
  id: string;
  source: string;
  target: string;
  //rule: string;
  type?: string;
  markerEnd?: {
    color?: string;
    type: MarkerType;
  };
  data: FlowchartEdgeData;
}

export const activitiesToNodes = (children: IActivity[]): FlowchartNode[] =>
  children
    .filter((c) => !!c.resourceId)
    .map<FlowchartNode>((item, index) => ({
      id: String(item.resourceId),
      resourceId: item.resourceId!,
      type: 'screen',
      draggable: false,
      position: { x: index * 200 + 50, y: 50 },
      data: {
        ...item,
      },
    }));

interface PlaceholderNodeAndEdge {
  node: FlowchartPlaceholderNode;
  edge: FlowchartEdge;
}

const createStartNode = (id: string, toScreenId: number): FlowchartStartNode => ({
  id,
  position: { x: 0, y: 0 },
  data: { toScreenId },
  draggable: false,
  type: 'start',
});

const createPlaceholderNode = (id: string, fromScreenId: number): FlowchartPlaceholderNode => ({
  id,
  position: { x: 0, y: 0 },
  data: { fromScreenId },
  draggable: false,
  type: 'placeholder',
});

const createPlaceholderEdge = (fromScreenId: string, toScreenId: string): FlowchartEdge => ({
  id: guid(),
  source: fromScreenId,
  target: toScreenId,
  type: 'placeholder',
  data: { completed: false },
});

interface HasResourceID {
  resourceId: number;
}

// Builds the start node with an edge to the first activity
export const buildStartingNode = (
  children: IActivity[],
  sequence: HasResourceID[],
): { node: FlowchartStartNode; edge: FlowchartEdge } => {
  const firstActivity = sequence.find((c) => !!c.resourceId);
  const nodeId = guid();
  return {
    node: createStartNode(nodeId, firstActivity?.resourceId || -1),
    edge: createPlaceholderEdge(nodeId, String(firstActivity?.resourceId)),
  };
};

export const buildPlaceholders = (
  children: IActivity[],
): { nodes: FlowchartPlaceholderNode[]; edges: FlowchartEdge[] } => {
  const placeholders: PlaceholderNodeAndEdge[] = children
    .filter((c) => !!c.resourceId)
    .map((item) => {
      const paths = item.authoring?.flowchart?.paths || [];
      const nodeId = guid();
      return paths.filter(isExitActivityPath).map((_path: AllPaths) => {
        return {
          node: createPlaceholderNode(nodeId, item.resourceId!),
          edge: createPlaceholderEdge(String(item.resourceId!), nodeId),
        };
      });
    })
    .flat();

  // Go from an array of { node, edge } to { nodes: [], edges: [] }
  return placeholders.reduce(
    (acc, item) => ({ nodes: [...acc.nodes, item.node], edges: [...acc.edges, item.edge] }),
    {
      nodes: [],
      edges: [],
    },
  );
};

export const buildEdges = (activities: IActivity[]): FlowchartEdge[] => {
  const endScreenId =
    activities.find((a) => a.authoring?.flowchart?.screenType === 'end_screen')?.resourceId || -1;
  return activities.map(buildEdgesForActivity(endScreenId)).flat();
};
