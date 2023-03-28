import * as React from 'react';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { Point } from './common';
import { throttle } from './timing';
import './ShapeEditor.scss';

const mapCoordsToPolygonProps = (coords: Immutable.List<number>) => {
  return {
    points: coords.join(','),
  };
};

const calculateCentroid = (coords: Immutable.List<number>): Point => {
  const x = coords.filter((x, index) => index % 2 === 0);
  const y = coords.filter((y, index) => index % 2 !== 0);
  const cx = (Math.min(...x.toArray()) + Math.max(...x.toArray())) / 2;
  const cy = (Math.min(...y.toArray()) + Math.max(...y.toArray())) / 2;

  return { x: cx, y: cy };
};

export interface PolygonEditorProps {
  id: string;
  label: string;
  coords: Immutable.List<number>;
  selected: boolean;
  boundingClientRect: Maybe<DOMRect>;
  onSelect: (id: string) => void;
  onEdit: (coords: Immutable.List<number>) => void;
}

export interface PolygonEditorState {
  newCoords: Maybe<Immutable.List<number>>;
  dragPointBegin: Maybe<Point>;
  dragMouseBegin: Maybe<Point>;
  dragPointIndices: Maybe<Point>;
}

/**
 * PolygonEditor React Component
 */
export class PolygonEditor extends React.PureComponent<PolygonEditorProps, PolygonEditorState> {
  constructor(props: PolygonEditorProps) {
    super(props);

    this.state = {
      newCoords: Maybe.nothing<Immutable.List<number>>(),
      dragPointBegin: Maybe.nothing<Point>(),
      dragMouseBegin: Maybe.nothing<Point>(),
      dragPointIndices: Maybe.nothing<Point>(),
    };

    this.beginResize = this.beginResize.bind(this);
    this.endResize = this.endResize.bind(this);
    this.onResizeDrag = throttle(this.onResizeDrag.bind(this), 25);
    this.beginMove = this.beginMove.bind(this);
    this.endMove = this.endMove.bind(this);
    this.onMoveDrag = throttle(this.onMoveDrag.bind(this), 25);
    this.onSelect = this.onSelect.bind(this);
  }

  beginResize(pointIndex: number, e: React.MouseEvent) {
    const { coords } = this.props;
    const { clientX, clientY } = e.nativeEvent;

    const coordIndex = pointIndex * 2;

    this.setState({
      dragPointBegin: Maybe.just({ x: coords.get(coordIndex)!, y: coords.get(coordIndex + 1)! }),
      dragMouseBegin: Maybe.just({ x: clientX, y: clientY }),
      dragPointIndices: Maybe.just({ x: coordIndex, y: coordIndex + 1 }),
    });

    // register global mouse listeners
    window.addEventListener('mousemove', this.onResizeDrag);
    window.addEventListener('mouseup', this.endResize);

    e.stopPropagation();
  }

  endResize(_e: any) {
    const { onEdit } = this.props;
    const { newCoords } = this.state;

    // unregister global mouse listeners
    window.removeEventListener('mousemove', this.onResizeDrag);
    window.removeEventListener('mouseup', this.endResize);

    newCoords.lift((coords) => onEdit(coords));

    this.setState({
      newCoords: Maybe.nothing<Immutable.List<number>>(),
      dragPointBegin: Maybe.nothing<Point>(),
      dragMouseBegin: Maybe.nothing<Point>(),
      dragPointIndices: Maybe.nothing<Point>(),
    });
  }

  onResizeDrag(e: MouseEvent) {
    const { coords, boundingClientRect } = this.props;
    const { newCoords, dragPointBegin, dragMouseBegin, dragPointIndices } = this.state;

    dragPointIndices.lift((dragPointIndicesVal) => {
      dragPointBegin.lift((dragPointBeginVal) => {
        dragMouseBegin.lift((dragMouseBeginVal) => {
          boundingClientRect.lift((boundingClient) => {
            const { left, top, width, height } = boundingClient;
            const { clientX, clientY } = e;

            // ensure new position is inside the bounds of the image
            const dragMouse = {
              x: Math.min(Math.max(clientX, left), left + width),
              y: Math.min(Math.max(clientY, top), top + height),
            };

            // calculate the offset distance from where the drag began to where the mouse is
            const offsets = {
              x: dragMouse.x - dragMouseBeginVal.x,
              y: dragMouse.y - dragMouseBeginVal.y,
            };

            // calculate the new point position using the offsets
            const newPointPosition = {
              x: dragPointBeginVal.x + offsets.x,
              y: dragPointBeginVal.y + offsets.y,
            };

            // update point location in state
            this.setState({
              newCoords: Maybe.just(
                newCoords
                  .valueOr(coords)
                  .set(dragPointIndicesVal.x, newPointPosition.x)
                  .set(dragPointIndicesVal.y, newPointPosition.y),
              ),
            });
          });
        });
      });
    });
  }

  beginMove(e: React.MouseEvent) {
    const { clientX, clientY } = e.nativeEvent;

    this.setState({
      dragMouseBegin: Maybe.just({ x: clientX, y: clientY }),
    });

    // register global mouse listeners
    window.addEventListener('mousemove', this.onMoveDrag);
    window.addEventListener('mouseup', this.endMove);

    e.stopPropagation();
  }

  endMove(_e: any) {
    const { onEdit } = this.props;
    const { newCoords } = this.state;

    // unregister global mouse listeners
    window.removeEventListener('mousemove', this.onMoveDrag);
    window.removeEventListener('mouseup', this.endMove);

    newCoords.lift((coords) => onEdit(coords));

    this.setState({
      newCoords: Maybe.nothing<Immutable.List<number>>(),
      dragPointBegin: Maybe.nothing<Point>(),
      dragMouseBegin: Maybe.nothing<Point>(),
      dragPointIndices: Maybe.nothing<Point>(),
    });
  }

  onMoveDrag(e: MouseEvent) {
    const { coords, boundingClientRect } = this.props;
    const { newCoords, dragMouseBegin } = this.state;

    dragMouseBegin.lift((dragMouseBeginVal) => {
      boundingClientRect.lift((boundingClient) => {
        const { left, top, width, height } = boundingClient;
        const { clientX, clientY } = e;

        const dragMouse = {
          x: Math.min(Math.max(clientX, left), left + width),
          y: Math.min(Math.max(clientY, top), top + height),
        };

        const offsets = {
          x: dragMouse.x - dragMouseBeginVal.x,
          y: dragMouse.y - dragMouseBeginVal.y,
        };

        // transform all points according to the offsets
        const calculatedCoords = newCoords
          .valueOr(coords)
          .map((coord, index) =>
            index % 2 === 0 ? coords.get(index)! + offsets.x : coords.get(index)! + offsets.y,
          )
          .toList();

        this.setState({
          newCoords: Maybe.just(calculatedCoords),
        });
      });
    });
  }

  onSelect(id: string, e: React.MouseEvent) {
    this.props.onSelect(id);
    e.stopPropagation();
  }

  renderResizeHandles(coords: Immutable.List<number>) {
    return (
      <React.Fragment>
        {coords
          .toArray()
          .reduce(
            (acc: Point[], val, index, array) =>
              index % 2 === 0 ? acc.concat({ x: array[index], y: array[index + 1] }) : acc,
            [],
          )
          .map((coord, i) => (
            <circle
              className="shape-handle shape-move"
              key={i}
              cx={coord.x}
              cy={coord.y}
              onMouseDown={(e) => this.beginResize(i, e)}
              onMouseUp={(e) => this.endResize(e)}
              onClick={(e) => e.stopPropagation()}
              r="5"
            />
          ))}
      </React.Fragment>
    );
  }

  render() {
    const { id, label, coords, selected } = this.props;
    const { newCoords } = this.state;
    const renderCoords = newCoords.valueOr(coords);

    // get the center point of the polygon
    const centeroid = calculateCentroid(newCoords.valueOr(coords));

    return (
      <React.Fragment>
        <polygon
          className={`shapeEditor ${selected ? 'shape-selected' : ''}`}
          onMouseDown={(e) => {
            this.onSelect(id, e);
            this.beginMove(e);
          }}
          onMouseUp={(e) => this.endMove(e)}
          {...mapCoordsToPolygonProps(renderCoords)}
        />
        <text className="shape-label" x={centeroid.x - 7} y={centeroid.y + 7}>
          {label}
        </text>
        {selected && this.renderResizeHandles(renderCoords)}
      </React.Fragment>
    );
  }
}
