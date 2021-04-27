import { BoundingRect, Point, Position } from 'components/editing/models/image/resizer/types';

// Width / height of resize handle in pixels
const HANDLE_SIZE = 4;
const offsetByResizeHandleSize = (styles: Point) =>
  Object.assign(styles, {
    left: styles.left - HANDLE_SIZE,
    top: styles.top - HANDLE_SIZE,
  });

export const styles = (position: 'border' | Position): { [k: string]: string } => {
  switch (position) {
    case 'border':
      return {};
    case 'nw':
      return { cursor: 'nw-resize' };
    case 'n':
      return { cursor: 'n-resize' };
    case 'ne':
      return { cursor: 'ne-resize' };
    case 'w':
      return { cursor: 'w-resize' };
    case 'e':
      return { cursor: 'e-resize' };
    case 'sw':
      return { cursor: 'sw-resize' };
    case 's':
      return { cursor: 's-resize' };
    case 'se':
      return { cursor: 'se-resize' };
  }
};

const positions = ({ left, top, width, height }: BoundingRect) => (
  position: 'border' | Position,
): Point | BoundingRect => {
  // Two cases: dragging or not
  // When not dragging, use below
  // When dragging, all nodes on that "side" can move, + border
  // keep bounding rect in state, pull from that. use this to set default values

  switch (position) {
    case 'border':
      return { left, top, width, height };
    case 'nw':
      return { left, top };
    case 'n':
      return { left: left + width / 2, top };
    case 'ne':
      return { left: left + width, top };
    case 'w':
      return { left, top: top + height / 2 };
    case 'e':
      return { left: left + width, top: top + height / 2 };
    case 'sw':
      return { left, top: top + height };
    case 's':
      return { left: left + width / 2, top: top + height };
    case 'se':
      return { left: left + width, top: top + height };
  }
};

export const resizeHandleStyles: any = (boundingRect: BoundingRect) => (
  position: 'border' | Position,
) =>
  Object.assign(
    position === 'border'
      ? positions(boundingRect)(position)
      : offsetByResizeHandleSize(positions(boundingRect)(position)),
    styles(position),
  );
