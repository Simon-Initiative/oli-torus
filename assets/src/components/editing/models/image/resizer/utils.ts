import { BoundingRect, Point, Position } from 'components/editing/models/image/resizer/types';
import { MousePosition } from 'components/editing/models/image/resizer/useMousePosition';

// Width / height of resize handle in pixels
const HANDLE_SIZE = 4;
const offsetByResizeHandleSize = (styles: Point) =>
  Object.assign(styles, {
    left: styles.left - HANDLE_SIZE,
    top: styles.top - HANDLE_SIZE,
  });

export const cursor = (position: 'border' | Position): { [k: string]: string } => {
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

export const resizeHandleStyles = (boundingRect: BoundingRect): any => (
  position: 'border' | Position,
) =>
  Object.assign(
    position === 'border'
      ? positions(boundingRect)(position)
      : offsetByResizeHandleSize(positions(boundingRect)(position)),
    cursor(position),
  );

export const clientBoundingRect = (element: HTMLElement): BoundingRect => {
  const { left, top, width, height } = element.getBoundingClientRect();
  return {
    top,
    left,
    width,
    height,
  };
};

export const offsetBoundingRect = (element: HTMLElement): BoundingRect => {
  const { offsetTop, offsetLeft, offsetWidth, offsetHeight } = element;
  return {
    top: offsetTop,
    left: offsetLeft,
    width: offsetWidth,
    height: offsetHeight,
  };
};

// Aspect ratio = width / height
const aspectRatioConversion = (
  data:
    | { width: number; height: number }
    | { width: number; aspectRatio: number }
    | { height: number; aspectRatio: number },
) => {
  switch (true) {
    case (data as any).width !== undefined && (data as any).height !== undefined:
      return (data as any).width / (data as any).height;
    case (data as any).width !== undefined && (data as any).aspectRatio !== undefined:
      return (data as any).width / (data as any).aspectRatio;
    case (data as any).height !== undefined && (data as any).aspectRatio !== undefined:
      return (data as any).height * (data as any).aspectRatio;
  }
};

// const maintainAspectRatio = (
//   initialBoundingRect: BoundingRect,
//   maybeFinalBoundingRect: BoundingRect,
// ): BoundingRect => {
//   // AR = width / height.
//   // height = width / AR
//   const aspectRatio = aspectRatioConversion(initialBoundingRect.width, initialBoundingRect.height);
//   console.log('aspectRatio', aspectRatio);

//   return Object.assign(maybeFinalBoundingRect, {
//     height: maybeFinalBoundingRect.width / aspectRatio,
//   });
// };

const normalize = (factor: number, data: { width: number } | { height: number }) => {};

/**
 * Resizing is split into three cases.
 * 1. Resizing from the W or E positions:
 *  a. Aspect ratio cannot be maintained, and the mouse position directly
 *  determines the change in width.
 * 2. Resizing from the NW, N, NE, SW, S, SW positions:
 *  a. Aspect ratio is maintained
 *  The mouse position determines the change in width or height by the dimension
 *  which has changed less. This allows maintaining aspect ratio
 *  b. aspect ratio is not maintained
 *  The mouse position directly determines the change in width and height
 * @param initialClientBoundingRect
 * @param initialOffsetBoundingRect
 * @param param2
 * @param dragHandle
 * @returns
 */
export const boundingRectFromMousePosition = (
  initialClientBoundingRect: BoundingRect,
  initialOffsetBoundingRect: BoundingRect,
  { x, y }: MousePosition,
  dragHandle: Position,
): BoundingRect => {
  const { top, left, width, height } = initialOffsetBoundingRect;
  let fromLeft = 0,
    fromTop = 0,
    difference = 0;

  const MIN_SIZE = 10;
  const atLeast = (a: number, min: number) => (a < min ? min : a);
  const atMost = (a: number, max: number) => (a > max ? max : a);

  switch (true) {
    case dragHandle === 'nw':
      // normalize below
      fromLeft = x - initialClientBoundingRect.left;
      fromTop = y - initialClientBoundingRect.top;
      difference = Math.min(fromLeft, fromTop);

      return {
        left: atMost(
          left + (difference === fromLeft ? difference : fromTop),
          left + width - MIN_SIZE,
        ),
        top: atMost(top + (difference === fromTop ? difference : fromLeft), height - MIN_SIZE),
        width: atLeast(width - (difference === fromLeft ? difference : fromTop), 2 * MIN_SIZE),
        height: atLeast(height - (difference === fromTop ? difference : fromLeft), 2 * MIN_SIZE),
      };
    case dragHandle === 'n':
      fromTop = initialClientBoundingRect.top - y;
      return {
        left: left,
        top: top + fromTop,
        width: width,
        height: height - fromTop,
      };
    case dragHandle === 'ne':
      fromLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      fromTop = initialClientBoundingRect.top - y;
      return {
        left: left,
        top: top + fromTop,
        width: width + fromLeft,
        height: height - fromTop,
      };
    case dragHandle === 'w':
      fromLeft = initialClientBoundingRect.left - x;
      return {
        left: left + fromLeft,
        top,
        width: width - fromLeft,
        height: height,
      };
    case dragHandle === 'e':
      fromLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      return {
        left: left,
        top: top,
        width: width + fromLeft,
        height: height,
      };
    case dragHandle === 'sw':
      fromLeft = initialClientBoundingRect.left - x;
      fromTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left + fromLeft,
        top: top,
        width: width - fromLeft,
        height: height + fromTop,
      };
    case dragHandle === 's':
      fromTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left,
        top: top,
        width: width,
        height: height + fromTop,
      };
    case dragHandle === 'se':
      fromLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      fromTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left,
        top: top,
        width: width + fromLeft,
        height: height + fromTop,
      };
    default:
      throw new Error('unhandled drag handle in Image Editor boundingRect');
  }
};

export const isCorner = (position: Position): boolean =>
  ['nw', 'ne', 'sw', 'se'].includes(position);
