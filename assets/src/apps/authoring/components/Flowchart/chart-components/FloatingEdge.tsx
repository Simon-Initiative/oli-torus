import React, { useCallback, useContext } from 'react';
import { useDrop } from 'react-dnd';
import { useStore, getBezierPath } from 'reactflow';
import { Icon } from '../../../../../components/misc/Icon';
import { FlowchartEdgeData } from '../flowchart-utils';
import { FlowchartEventContext } from '../FlowchartEventContext';
import { screenTypes } from '../screens/screen-factories';

import { getEdgeParams } from './utils';

const boxSize = 30;

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
  const sourceId = sourceNode.data.resourceId;
  const targetId = targetNode.data.resourceId;

  const { sx, sy, tx, ty, sourcePos, targetPos } = getEdgeParams(sourceNode, targetNode);

  const [edgePath, labelX, labelY] = getBezierPath({
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
    <>
      <path
        id={id}
        className="react-flow__edge-path"
        d={edgePath}
        strokeDasharray={dash}
        markerEnd={markerEnd}
        stroke="#22f"
        style={style}
      />
      <foreignObject
        width={boxSize}
        height={boxSize}
        x={labelX - boxSize / 2}
        y={labelY - boxSize / 2}
        className="edgebutton-foreignobject"
        requiredExtensions="http://www.w3.org/1999/xhtml"
      >
        <DropSpot source={sourceId} target={targetId} />
      </foreignObject>
    </>
  );
};

const DropSpot: React.FC<{ source: number; target: number }> = ({ source, target }) => {
  const { onAddScreen } = useContext(FlowchartEventContext);

  const onDrop = (item: any) => {
    onAddScreen({ prevNodeId: source, nextNodeId: target, screenType: item.screenType });
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
  const className = hover ? 'edgeDropSpot hover' : 'edgeDropSpot';
  return (
    <div className={className} ref={drop}>
      {hover && <Icon icon="add" />}
    </div>
  );
};
