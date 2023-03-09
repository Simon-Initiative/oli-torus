import React, { useCallback } from 'react';
import { useStore, getBezierPath } from 'reactflow';
import { FlowchartEdgeData } from '../flowchart-utils';

import { getEdgeParams } from './utils';

interface FloatingEdgeProps {
  id: string;
  source: string;
  target: string;
  markerEnd?: string;
  style?: React.CSSProperties;
  data?: FlowchartEdgeData;
}

export const FloatingEdge: React.FC<FloatingEdgeProps> = ({
  id,
  source,
  target,
  markerEnd,
  style,
  data,
}) => {
  const sourceNode = useStore(useCallback((store) => store.nodeInternals.get(source), [source]));
  const targetNode = useStore(useCallback((store) => store.nodeInternals.get(target), [target]));

  if (!sourceNode || !targetNode) {
    return null;
  }

  const { sx, sy, tx, ty, sourcePos, targetPos } = getEdgeParams(sourceNode, targetNode);

  const [edgePath] = getBezierPath({
    sourceX: sx,
    sourceY: sy,
    sourcePosition: sourcePos,
    targetPosition: targetPos,
    targetX: tx,
    targetY: ty,
  });

  // Dashed line on incomplete edges
  const dash = data?.completed ? undefined : '4 4';

  return (
    <path
      id={id}
      className="react-flow__edge-path"
      d={edgePath}
      strokeDasharray={dash}
      markerEnd={markerEnd}
      stroke="#22f"
      style={style}
    />
  );
};
