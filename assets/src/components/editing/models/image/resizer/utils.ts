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
): any => {
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

export const boundingRectFromMousePosition = (
  initialClientBoundingRect: BoundingRect,
  initialOffsetBoundingRect: BoundingRect,
  { x, y }: MousePosition,
  dragHandle: Position,
): BoundingRect => {
  const {
    top: offsetTop,
    left: offsetLeft,
    width: offsetWidth,
    height: offsetHeight,
  } = initialOffsetBoundingRect;
  const {
    top: clientTop,
    left: clientLeft,
    width: clientWidth,
    height: clientHeight,
  } = initialClientBoundingRect;
  let fromLeft = 0,
    fromTop = 0;

  const MIN_SIZE = 10;
  const atLeast = (a: number, min: number) => (a < min ? min : a);
  const atMost = (a: number, max: number) => (a > max ? max : a);
  const aspectRatio: number = aspectRatioConversion({ width: offsetWidth, height: offsetHeight });
  const delta = (first: number, second: number) => Math.min(first, second);

  const constrain = (first: number, second: number) =>
    first === delta(first, second) ? first : second;

  switch (true) {
    case dragHandle === 'nw':
      fromLeft = x - clientLeft;
      fromTop = aspectRatioConversion({ height: y - clientTop, aspectRatio });

      return {
        left: atMost(
          offsetLeft + constrain(fromLeft, fromTop),
          offsetLeft + offsetWidth - MIN_SIZE,
        ),
        top: atMost(offsetTop + constrain(fromTop, fromLeft), offsetHeight - MIN_SIZE),
        width: atLeast(offsetWidth - constrain(fromLeft, fromTop), 2 * MIN_SIZE),
        height: atLeast(offsetHeight - constrain(fromTop, fromLeft), 2 * MIN_SIZE),
      };
    case dragHandle === 'ne':
      fromLeft = x - (clientLeft + clientWidth);
      fromTop = y - clientTop;
      return {
        left: offsetLeft,
        top: offsetTop + constrain(fromTop, fromLeft),
        width: offsetWidth + constrain(fromLeft, fromTop),
        height: offsetHeight - constrain(fromTop, fromLeft),
      };
    case dragHandle === 'sw':
      fromLeft = x - clientLeft;
      fromTop = y - (clientTop + clientHeight);
      return {
        left: offsetLeft + constrain(fromLeft, fromTop),
        top: offsetTop,
        width: offsetWidth - constrain(fromLeft, fromTop),
        height: offsetHeight + constrain(fromTop, fromLeft),
      };
    case dragHandle === 'se':
      fromLeft = x - (clientLeft + clientWidth);
      fromTop = y - (clientTop + clientHeight);
      return {
        left: offsetLeft,
        top: offsetTop,
        width: offsetWidth + constrain(fromLeft, fromTop),
        height: offsetHeight + constrain(fromTop, fromLeft),
      };
    default:
      throw new Error('unhandled drag handle in Image Editor boundingRect');
  }
};

export const isCorner = (position: Position): boolean =>
  ['nw', 'ne', 'sw', 'se'].includes(position);
