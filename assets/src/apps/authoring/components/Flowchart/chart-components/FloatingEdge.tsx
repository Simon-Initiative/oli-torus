import React, { useCallback, useContext } from 'react';
import { useDrop } from 'react-dnd';
import {
  useStore,
  /*getBezierPath*/
} from 'reactflow';
import { Icon } from '../../../../../components/misc/Icon';
import { FlowchartEventContext } from '../FlowchartEventContext';
import { FlowchartEdgeData } from '../flowchart-utils';
import { screenTypes } from '../screens/screen-factories';

const boxSize = 24;

interface FloatingEdgeProps {
  id: string;
  source: string;
  target: string;
  markerEnd?: string;
  style?: React.CSSProperties;
  data?: FlowchartEdgeData;
}

const SVGOffset = 92;
const createCurvedPath = (points: { x: number; y: number }[]): string => {
  switch (points.length) {
    case 3:
      return (
        `M${points[0].x + SVGOffset},${points[0].y + SVGOffset}` +
        `Q${points[1].x + SVGOffset},${points[1].y + SVGOffset} ` +
        `${points[2].x + SVGOffset},${points[2].y + SVGOffset}`
      );
    case 4:
      return (
        `M${points[0].x + SVGOffset},${points[0].y + SVGOffset}` +
        `C${points[1].x + SVGOffset},${points[1].y + SVGOffset} ` +
        `${points[2].x + SVGOffset},${points[2].y + SVGOffset}` +
        `${points[3].x + SVGOffset},${points[3].y + SVGOffset}`
      );
    case 5:
      return createCurvedPath(points.slice(0, 3)) + ' ' + createCurvedPath(points.slice(2));

    default:
      return points
        .map((p, i) =>
          i === 0
            ? `M${p.x + SVGOffset},${p.y + SVGOffset}`
            : `L${p.x + SVGOffset},${p.y + SVGOffset}`,
        )
        .join('');
  }
};

function findCurveCenter(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  x3: number,
  y3: number,
): { x: number; y: number } {
  const cx = (x1 + 2 * x2 + x3) / 4;
  const cy = (y1 + 2 * y2 + y3) / 4;
  return { x: cx, y: cy };
}
const findLabelPoint = (points: { x: number; y: number }[]): { labelX: number; labelY: number } => {
  if (points.length === 3) {
    const { x, y } = findCurveCenter(
      points[0].x + SVGOffset,
      points[0].y + SVGOffset,
      points[1].x + SVGOffset,
      points[1].y + SVGOffset,
      points[2].x + SVGOffset,
      points[2].y + SVGOffset,
    );
    return { labelX: x, labelY: y };
  }

  const center = points[Math.round(points.length / 2) - 1];
  const labelX = center.x + SVGOffset;
  const labelY = center.y + SVGOffset;
  return { labelX, labelY };
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

  const { labelX, labelY } = findLabelPoint(dagrePoints);

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

  const [{ isDragging, canDrop }, drop] = useDrop(() => ({
    accept: screenTypes,
    drop: onDrop,
    collect: (monitor) => ({
      // isOver: monitor.isOver(),
      canDrop: monitor.canDrop(),
      isDragging: !!monitor.getItemType(),
    }),
  }));

  const hover = isDragging && canDrop;
  const className = hover ? 'edgeDropSpot hover' : 'edgeDropSpot';
  return (
    <div className={className} ref={drop}>
      {hover && <Icon icon="add" />}
    </div>
  );
};
