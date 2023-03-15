import React, { useCallback } from 'react';
import { useStore, getBezierPath } from 'reactflow';

import { getEdgeParams } from './utils';

interface FloatingEdgeProps {
  id: string;
  source: string;
  target: string;
  markerEnd?: string;
  style?: React.CSSProperties;
}

export const PlaceholderEdge: React.FC<FloatingEdgeProps> = ({
  id,
  source,
  target,
  markerEnd,
  style,
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

  return (
    <path
      id={id}
      d={edgePath}
      fill="none"
      markerEnd={markerEnd}
      stroke="#b3b4b7"
      strokeWidth={2}
      style={style}
    />
  );
};
