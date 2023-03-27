import React, { useCallback, useContext } from 'react';
import { useDrop } from 'react-dnd';
import { useStore /*getBezierPath*/ } from 'reactflow';
import { Icon } from '../../../../../components/misc/Icon';
import { FlowchartEdgeData } from '../flowchart-utils';
import { FlowchartEventContext } from '../FlowchartEventContext';
import { screenTypes } from '../screens/screen-factories';

const boxSize = 30;

interface FloatingEdgeProps {
  id: string;
  source: string;
  target: string;
  markerEnd?: string;
  style?: React.CSSProperties;
  data?: FlowchartEdgeData;
}

const createCurvedPath = (points: { x: number; y: number }[]): string => {
  switch (points.length) {
    case 3:
      return (
        `M${points[0].x + 65},${points[0].y + 65}` +
        `Q${points[1].x + 65},${points[1].y + 65} ` +
        `${points[2].x + 65},${points[2].y + 65}`
      );
    case 4:
      return (
        `M${points[0].x + 65},${points[0].y + 65}` +
        `C${points[1].x + 65},${points[1].y + 65} ` +
        `${points[2].x + 65},${points[2].y + 65}` +
        `${points[3].x + 65},${points[3].y + 65}`
      );
    case 5:
      return createCurvedPath(points.slice(0, 3)) + ' ' + createCurvedPath(points.slice(2));

    default:
      return points
        .map((p, i) => (i === 0 ? `M${p.x + 65},${p.y + 65}` : `L${p.x + 65},${p.y + 65}`))
        .join('');
  }
};

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

  const dagrePoints = data?.points || [];

  const center = dagrePoints[Math.floor(dagrePoints.length / 2)];
  const labelX = center.x + 65;
  const labelY = center.y + 65;

  // Dashed line on incomplete edges
  const dash = data?.completed ? undefined : '4 4';

  const edgePath = createCurvedPath(dagrePoints);

  // Color: 22f
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
