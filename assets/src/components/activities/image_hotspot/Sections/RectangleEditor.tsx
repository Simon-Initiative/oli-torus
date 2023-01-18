import * as React from 'react';
import './ShapeEditor.scss';
import * as Immutable from 'immutable';
import { throttle } from './timing';
import { Maybe } from 'tsmonad';
import { Point } from './common';

const mapCoordsToRectProps = (coords: Immutable.List<number>) => {
  return {
    x: coords.get(0),
    y: coords.get(1),
    width: coords.get(2)! - coords.get(0)!,
    height: coords.get(3)! - coords.get(1)!,
  };
};

export interface RectangleEditorProps {
  id: string;
  label: string;
  coords: Immutable.List<number>;
  selected: boolean;
  boundingClientRect: Maybe<DOMRect>;
  onSelect: (id: string) => void;
  onEdit: (coords: Immutable.List<number>) => void;
}

export interface RectangleEditorState {
  newCoords: Maybe<Immutable.List<number>>;
  dragPointBegin: Maybe<Point>;
  dragMouseBegin: Maybe<Point>;
  dragPointIndices: Maybe<Point>;
}

/**
 * RectangleEditor React Component
 */
export class RectangleEditor extends React.PureComponent<
  RectangleEditorProps,
  RectangleEditorState
> {
  constructor(props: RectangleEditorProps) {
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

  beginResize(pointIndices: Point, e: React.MouseEvent) {
    const { coords } = this.props;
    const { clientX, clientY } = e.nativeEvent;

    this.setState({
      dragPointBegin: Maybe.just({
        x: coords.get(pointIndices.x)!,
        y: coords.get(pointIndices.y)!,
      }),
      dragMouseBegin: Maybe.just({ x: clientX, y: clientY }),
      dragPointIndices: Maybe.just({ x: pointIndices.x, y: pointIndices.y }),
    });

    // register global mouse listeners
    window.addEventListener('mousemove', this.onResizeDrag);
    window.addEventListener('mouseup', this.endResize);

    // stop event propagation to keep item selected
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
            let newPointPosition = {
              x: dragPointBeginVal.x + offsets.x,
              y: dragPointBeginVal.y + offsets.y,
            };

            // maintain minimum hotspot size using opposite point as constraint
            const MINIMUM_SIZE_PX = 30;
            const constraintIndices = {
              x: (dragPointIndicesVal.x + 2) % 4, // opposite point x coords index
              y: (dragPointIndicesVal.y + 2) % 4, // opposite point y coords index
            };
            newPointPosition = {
              x:
                constraintIndices.x < dragPointIndicesVal.x
                  ? Math.max(newPointPosition.x, coords.get(constraintIndices.x)! + MINIMUM_SIZE_PX)
                  : Math.min(
                      newPointPosition.x,
                      coords.get(constraintIndices.x)! - MINIMUM_SIZE_PX,
                    ),
              y:
                constraintIndices.y < dragPointIndicesVal.y
                  ? Math.max(newPointPosition.y, coords.get(constraintIndices.y)! + MINIMUM_SIZE_PX)
                  : Math.min(
                      newPointPosition.y,
                      coords.get(constraintIndices.y)! - MINIMUM_SIZE_PX,
                    ),
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
    const { coords } = this.props;
    const { clientX, clientY } = e.nativeEvent;

    this.setState({
      dragPointBegin: Maybe.just({ x: coords.get(0)!, y: coords.get(1)! }),
      dragMouseBegin: Maybe.just({ x: clientX, y: clientY }),
    });

    // register global mouse listeners
    window.addEventListener('mousemove', this.onMoveDrag);
    window.addEventListener('mouseup', this.endMove);
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
    const { newCoords, dragPointBegin, dragMouseBegin } = this.state;

    dragPointBegin.lift((dragPointBeginVal) => {
      dragMouseBegin.lift((dragMouseBeginVal) => {
        boundingClientRect.lift((boundingClient) => {
          const { clientX, clientY } = e;

          const offsets = {
            x: clientX - dragMouseBeginVal.x,
            y: clientY - dragMouseBeginVal.y,
          };

          const { width, height } = mapCoordsToRectProps(coords);

          let calculatedCoords = {
            x1: dragPointBeginVal.x + offsets.x,
            y1: dragPointBeginVal.y + offsets.y,
            x2: dragPointBeginVal.x + offsets.x + width,
            y2: dragPointBeginVal.y + offsets.y + height,
          };

          // ensure new location is inside the hotspot area
          const halfWidth = Math.floor(width / 2);
          const halfHeight = Math.floor(height / 2);
          calculatedCoords = {
            x1: Math.min(
              Math.max(calculatedCoords.x1, 0 - halfWidth),
              boundingClient.width - halfWidth,
            ),
            y1: Math.min(
              Math.max(calculatedCoords.y1, 0 - halfHeight),
              boundingClient.height - halfHeight,
            ),
            x2: Math.min(
              Math.max(calculatedCoords.x2, halfWidth),
              boundingClient.width + halfWidth,
            ),
            y2: Math.min(
              Math.max(calculatedCoords.y2, halfHeight),
              boundingClient.height + halfHeight,
            ),
          };

          this.setState({
            newCoords: Maybe.just(
              newCoords
                .valueOr(coords)
                .set(0, calculatedCoords.x1)
                .set(1, calculatedCoords.y1)
                .set(2, calculatedCoords.x2)
                .set(3, calculatedCoords.y2),
            ),
          });
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
        <circle
          className="shape-handle shape-nwse"
          cx={coords.get(0)}
          cy={coords.get(1)}
          onMouseDown={(e) => this.beginResize({ x: 0, y: 1 }, e)}
          onMouseUp={(e) => this.endResize(e)}
          onClick={(e) => e.stopPropagation()}
          r="5"
        />
        <circle
          className="shape-handle shape-nesw"
          cx={coords.get(0)}
          cy={coords.get(3)}
          onMouseDown={(e) => this.beginResize({ x: 0, y: 3 }, e)}
          onMouseUp={(e) => this.endResize(e)}
          onClick={(e) => e.stopPropagation()}
          r="5"
        />
        <circle
          className="shape-handle shape-nesw"
          cx={coords.get(2)}
          cy={coords.get(1)}
          onMouseDown={(e) => this.beginResize({ x: 2, y: 1 }, e)}
          onMouseUp={(e) => this.endResize(e)}
          onClick={(e) => e.stopPropagation()}
          r="5"
        />
        <circle
          className="shape-handle shape-nwse"
          cx={coords.get(2)}
          cy={coords.get(3)}
          onMouseDown={(e) => this.beginResize({ x: 2, y: 3 }, e)}
          onMouseUp={(e) => this.endResize(e)}
          onClick={(e) => e.stopPropagation()}
          r="5"
        />
      </React.Fragment>
    );
  }

  render() {
    const { id, label, coords, selected } = this.props;
    const { newCoords } = this.state;
    const renderCoords = newCoords.valueOr(coords);

    return (
      <React.Fragment>
        <rect
          className={`shapeEditor ${selected ? 'shape-selected' : ''}`}
          onMouseDown={(e) => {
            this.onSelect(id, e);
            this.beginMove(e);
          }}
          onMouseUp={(e) => this.endMove(e)}
          {...mapCoordsToRectProps(renderCoords)}
        />
        <text
          className="shape-label"
          x={
            renderCoords.get(0)! + Math.floor((renderCoords.get(2)! - renderCoords.get(0)!) / 2) - 7
          }
          y={
            renderCoords.get(1)! + Math.floor((renderCoords.get(3)! - renderCoords.get(1)!) / 2) + 7
          }
        >
          {label}
        </text>
        {selected && this.renderResizeHandles(renderCoords)}
      </React.Fragment>
    );
  }
}
