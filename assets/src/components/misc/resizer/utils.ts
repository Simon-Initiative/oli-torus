import { BoundingRect, Point, Position } from 'components/misc/resizer/types';
import { MousePosition } from 'components/misc/resizer/useMousePosition';

const HANDLE_CENTER_IN_PIXELS = 4;
const offsetByResizeHandleSize = (styles: Point) =>
  Object.assign(styles, {
    left: styles.left - HANDLE_CENTER_IN_PIXELS,
    top: styles.top - HANDLE_CENTER_IN_PIXELS,
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

const proportionalWidthAndHeight = (
  { width: initialWidth, height: initialHeight }: BoundingRect,
  boundaryWidth: number,
  boundaryHeight: number,
) => {
  // initialWidth / initialHeight == scaledWidth / scaledHeight
  const scaledHeight = initialHeight / (initialWidth / boundaryWidth);
  const scaledWidth = initialWidth / (initialHeight / boundaryHeight);

  // Constrain resizing to the smaller value of boundary width and height
  if (scaledHeight < boundaryHeight) {
    return {
      width: scaledWidth,
      height: boundaryHeight,
    };
  }
  return {
    width: boundaryWidth,
    height: scaledHeight,
  };
};

export const boundingRectFromMousePosition = (
  initialClientBoundingRect: BoundingRect,
  initialOffsetBoundingRect: BoundingRect,
  mousePosition: MousePosition,
  dragHandle: Position,
): BoundingRect =>
  constrainRect(
    boundingRectHelper(
      initialClientBoundingRect,
      initialOffsetBoundingRect,
      mousePosition,
      dragHandle,
    ),
    initialOffsetBoundingRect,
  );

const constrainRect = (
  { top, left, width, height }: BoundingRect,
  { top: initialTop, left: initialLeft, width: initialWidth, height: initialHeight }: BoundingRect,
) => {
  const MIN_SIZE = 10;
  const atLeast = (a: number, min: number) => (a < min ? min : a);
  const atMost = (a: number, max: number) => (a > max ? max : a);

  return {
    top: atMost(top, initialTop + initialHeight - MIN_SIZE),
    left: atMost(left, initialLeft + initialWidth - MIN_SIZE),
    width: atLeast(width, MIN_SIZE),
    height: atLeast(height, MIN_SIZE),
  };
};

const boundingRectHelper = (
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
  let dw = 0,
    dh = 0,
    proportional;

  switch (true) {
    case dragHandle === 'nw':
      dw = x - clientLeft;
      dh = y - clientTop;

      proportional = proportionalWidthAndHeight(
        initialOffsetBoundingRect,
        offsetWidth - dw,
        offsetHeight - dh,
      );

      return {
        left: offsetLeft + offsetWidth - proportional.width,
        top: offsetTop + offsetHeight - proportional.height,
        width: proportional.width,
        height: proportional.height,
      };
    case dragHandle === 'n':
      dw = 0;
      dh = y - clientTop;

      return {
        left: offsetLeft,
        top: offsetTop + dh,
        width: offsetWidth,
        height: offsetHeight - dh,
      };
    case dragHandle === 'ne':
      dw = clientLeft + clientWidth - x;
      dh = y - clientTop;

      proportional = proportionalWidthAndHeight(
        initialOffsetBoundingRect,
        offsetWidth - dw,
        offsetHeight - dh,
      );
      return {
        left: offsetLeft,
        top: offsetTop + offsetHeight - proportional.height,
        width: proportional.width,
        height: proportional.height,
      };
    case dragHandle === 'w':
      dw = x - clientLeft;
      dh = 0;

      return {
        left: offsetLeft + dw,
        top: offsetTop,
        width: offsetWidth - dw,
        height: offsetHeight,
      };
    case dragHandle === 'e':
      dw = x - (clientLeft + clientWidth);
      dh = 0;

      return {
        left: offsetLeft,
        top: offsetTop,
        width: offsetWidth - dw,
        height: offsetHeight,
      };
    case dragHandle === 'sw':
      dw = x - clientLeft;
      dh = clientTop + clientHeight - y;

      proportional = proportionalWidthAndHeight(
        initialOffsetBoundingRect,
        offsetWidth - dw,
        offsetHeight - dh,
      );

      return {
        left: offsetLeft + offsetWidth - proportional.width,
        top: offsetTop,
        width: proportional.width,
        height: proportional.height,
      };
    case dragHandle === 's':
      dw = 0;
      dh = clientTop + clientHeight - y;

      return {
        left: offsetLeft,
        top: offsetTop,
        width: offsetWidth,
        height: offsetHeight - dh,
      };
    case dragHandle === 'se':
      dw = clientLeft + clientWidth - x;
      dh = clientTop + clientHeight - y;

      proportional = proportionalWidthAndHeight(
        initialOffsetBoundingRect,
        offsetWidth - dw,
        offsetHeight - dh,
      );
      return {
        left: offsetLeft,
        top: offsetTop,
        width: proportional.width,
        height: proportional.height,
      };
    default:
      throw new Error('unhandled drag handle in Image Editor boundingRect: ' + dragHandle);
  }
};
