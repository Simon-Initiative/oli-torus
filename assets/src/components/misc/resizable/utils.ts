import { BoundingRect, Point, Handle } from 'components/misc/resizable/types';
import { MousePosition } from 'components/misc/resizable/useMousePosition';

const HANDLE_CENTER_IN_PIXELS = 8;
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
  if (position === 'border') return { top: 0, left: 0, width: rect.width, height: rect.height };
  if (position === 'e') return { left: rect.width, top: rect.height / 2 };
  if (position === 's') return { left: rect.width / 2, top: rect.height };
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

const proportionally = (initial: BoundingRect, targetWidth: number, targetHeight: number) => {
  // aspectRatio
  // === initial.width / initial.height
  // === scaledWidth / scaledHeight
  // Get both scaled values, and only use one.
  const scaledHeight = initial.height / (initial.width / targetWidth || 1);
  const scaledWidth = initial.width / (initial.height / targetHeight || 1);

  // If changing the height, use the scaledWidth to
  // maintain aspect ratio. Otherwise, use scaledHeight.
  if (targetHeight !== initial.height)
    return {
      width: scaledWidth,
      height: targetHeight,
    };

  return {
    width: targetWidth,
    height: scaledHeight,
  };
};

const constrained = (resized: BoundingRect) => {
  const MIN_SIZE = 10;
  const atLeast = (a: number, min: number) => (a < min ? min : a);

  return {
    ...resized,
    width: atLeast(resized.width, MIN_SIZE),
    height: atLeast(resized.height, MIN_SIZE),
  };
};

const _rectFromCursor = (
  initial: DOMRect,
  cursor: MousePosition,
  handle?: Handle,
): BoundingRect => {
  const dh = cursor.y - initial.bottom; // > 0: larger, < 0: smaller
  const dw = cursor.x - initial.right; // > 0: larger, < 0: smaller

  // East: only look at dw
  // South: only look at dh
  const proportional =
    handle === 'e'
      ? proportionally(initial, initial.width + dw, initial.height)
      : handle === 's'
      ? proportionally(initial, initial.width, initial.height + dh)
      : initial;

  return {
    left: initial.left,
    top: initial.top,
    width: proportional.width,
    height: proportional.height,
  };
};

export const rectFromCursor = (
  initial: DOMRect,
  cursor: MousePosition,
  handle?: Handle,
): BoundingRect => constrained(_rectFromCursor(initial, cursor, handle));
