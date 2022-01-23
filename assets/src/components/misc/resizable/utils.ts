import { BoundingRect, Point, Handle } from 'components/misc/resizable/types';
import { MousePosition } from 'components/misc/resizable/useMousePosition';

const HANDLE_CENTER_IN_PIXELS = 4;
const offsetByHandleSize = (styles: Point) => ({
  ...styles,
  ...{
    left: styles.left - HANDLE_CENTER_IN_PIXELS,
    top: styles.top - HANDLE_CENTER_IN_PIXELS,
  },
});

export const cursor = (position: 'border' | Handle): { [k: string]: string } => {
  if (position === 'border') return {};
  if (position === 'e') return { cursor: 'e-resize' };
  if (position === 's') return { cursor: 's-resize' };
  throw new Error('Unexpected position in `cursor`, ' + position);
};

const positions = (rect: BoundingRect, position: 'border' | Handle): Point | BoundingRect => {
  if (position === 'border') return rect;
  if (position === 'e') return { left: rect.left + rect.width, top: rect.top + rect.height / 2 };
  if (position === 's') return { left: rect.left + rect.width / 2, top: rect.top + rect.height };
  throw new Error('Unexpected position in `positions`, ' + position);
};

export const resizeHandleStyles = (
  rect: BoundingRect,
  handle: 'border' | Handle,
): Partial<BoundingRect> => {
  const positioned =
    handle === 'border' ? positions(rect, handle) : offsetByHandleSize(positions(rect, handle));
  return { ...positioned, ...cursor(handle) };
};

export const offset = (element: HTMLElement): BoundingRect => ({
  top: element.offsetTop,
  left: element.offsetLeft,
  width: element.offsetWidth,
  height: element.offsetHeight,
});

const proportionally = (initial: BoundingRect, width: number, height: number) => {
  console.log('initial wh, wh', initial.width, initial.height, width, height);

  // initial.width / initial.height == scaledWidth / scaledHeight
  const scaledHeight = initial.height / (initial.width / width || 1);
  const scaledWidth = initial.width / (initial.height / height || 1);

  console.log('new width and height', scaledWidth, scaledHeight);

  // Constrain resizing to the smaller value of boundary width and height
  if (scaledHeight < height)
    return {
      width: scaledWidth,
      height: height,
    };

  return {
    width,
    height: scaledHeight,
  };
};

const constrained = (resized: BoundingRect) => {
  const MIN_SIZE = 10;
  const atLeast = (a: number, min: number) => (a < min ? min : a);

  console.log('constrained', {
    ...resized,
    width: atLeast(resized.width, MIN_SIZE),
    height: atLeast(resized.height, MIN_SIZE),
  });

  return {
    ...resized,
    width: atLeast(resized.width, MIN_SIZE),
    height: atLeast(resized.height, MIN_SIZE),
  };
};

const boundingRectHelper = (
  initial: DOMRect,
  mouse: MousePosition,
  position: Handle,
): BoundingRect => {
  const initialBottom = initial.bottom + window.scrollY;
  const initialRight = initial.right + window.scrollX;
  const dh = mouse.y - initialBottom; // > 0: larger, < 0: smaller
  const dw = mouse.x - initialRight; // > 0: larger, < 0: smaller

  if (position === 'e') {
    const proportional = proportionally(initial, initial.width + dw, initial.height);

    console.log('proportional', proportional);

    return {
      left: initial.left + window.scrollX,
      top: initial.top + window.scrollY,
      width: proportional.width,
      height: proportional.height,
    };
  }

  if (position === 's') {
    const proportional = proportionally(initial, initial.width, initial.height + dh);

    return {
      left: initial.left + window.scrollX,
      top: initial.top + window.scrollY,
      width: proportional.width,
      height: proportional.height,
    };
  }

  throw new Error('unhandled drag handle in Image Editor boundingRect: ' + position);
};

export const boundingRect = (
  initial: DOMRect,
  mouse: MousePosition,
  dragHandle: Handle,
): BoundingRect => constrained(boundingRectHelper(initial, mouse, dragHandle));
