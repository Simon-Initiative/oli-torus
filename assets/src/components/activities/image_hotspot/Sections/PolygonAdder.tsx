import * as React from 'react';
import { Point } from './common';
import { throttle } from './timing';
import './ShapeEditor.scss';

const coordsToList = (coords: number[]) => {
  return {
    points: coords.join(','),
  };
};

const outsideRect = (x: number, y: number, rect: DOMRect) => {
  const { left, top, width, height } = rect;
  return x < left || x > left + width || y < top || y > top + height;
};

// clean coordinate array by collapsing successive duplicate points into single point
const collapseDups = (coords: number[]) => {
  const newCoords: number[] = [];
  for (let i = 0, j = 0; i < coords.length; i += 2) {
    // copy pair if first element or distinct from predecessor
    if (i === 0 || coords[i] !== coords[i - 2] || coords[i + 1] !== coords[i - 1]) {
      newCoords[j++] = coords[i];
      newCoords[j++] = coords[i + 1];
    }
  }
  return newCoords;
};

export interface PolygonAdderProps {
  boundingClientRect: DOMRect;
  onEdit: (coords: number[]) => void;
}

export interface PolygonAdderState {
  coords: number[];
}

/**
 * PolygonAdder React Component
 */
export class PolygonAdder extends React.PureComponent<PolygonAdderProps, PolygonAdderState> {
  constructor(props: PolygonAdderProps) {
    super(props);

    this.state = { coords: [] };

    this.onClick = this.onClick.bind(this);
    // to track mouse while moving to potential new point
    this.onMouseMove = throttle(this.onMouseMove.bind(this), 25);
  }

  onClick(e: MouseEvent) {
    const { boundingClientRect } = this.props;
    const { coords } = this.state;

    const { left, top } = boundingClientRect;
    const { clientX, clientY } = e;
    // convert to image coords. Round because client rect can be fractional
    const localX = Math.round(clientX - left);
    const localY = Math.round(clientY - top);

    // Finish poly on dblclick (detail > 1) or click outside image bounds
    if (e.detail > 1 || outsideRect(clientX, clientY, boundingClientRect)) {
      window.removeEventListener('mousemove', this.onMouseMove);
      // Collapse successive duplicate points to help prevent adding degenerate polys
      // Caller will ignore if nPoints remaining < 3.
      this.props.onEdit(collapseDups(coords.slice(0, coords.length - 2)));
      return;
    }

    // update last point in coords, adding tentative next point for move tracking
    const newCoords = [...coords.slice(0, coords.length - 2), localX, localY, localX, localY];
    this.setState({ coords: newCoords });
    window.addEventListener('mousemove', this.onMouseMove);

    e.stopPropagation();
  }

  onMouseMove(e: MouseEvent) {
    const { boundingClientRect } = this.props;
    const { coords } = this.state;

    const { left, top } = boundingClientRect;
    const { clientX, clientY } = e;

    if (outsideRect(clientX, clientY, boundingClientRect)) return;

    const localX = Math.round(clientX - left);
    const localY = Math.round(clientY - top);

    // modify tentative last point
    this.setState({
      coords: [...coords.slice(0, coords.length - 2), localX, localY],
    });
  }

  renderResizeHandles(coords: number[]) {
    return (
      <React.Fragment>
        {coords
          .reduce(
            (acc: Point[], val, index, array) =>
              index % 2 === 0 ? acc.concat({ x: array[index], y: array[index + 1] }) : acc,
            [],
          )
          .map((coord, i) => (
            <circle className="shape-handle" key={i} cx={coord.x} cy={coord.y} r="5" />
          ))}
      </React.Fragment>
    );
  }

  componentDidMount() {
    window.addEventListener('click', this.onClick);
  }

  componentWillUnmount() {
    window.removeEventListener('click', this.onClick);
  }

  render() {
    const { coords } = this.state;

    return (
      <React.Fragment>
        <polyline className={`shapeEditor shape-selected`} {...coordsToList(coords)} />
        {this.renderResizeHandles(coords)}
      </React.Fragment>
    );
  }
}
