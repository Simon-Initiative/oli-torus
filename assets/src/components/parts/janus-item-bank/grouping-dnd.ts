import { CollisionDetection, Modifier, rectIntersection } from '@dnd-kit/core';

const getActivatorCoordinates = (event: Event): { x: number; y: number } | null => {
  if ('clientX' in event && typeof (event as MouseEvent).clientX === 'number') {
    return { x: (event as MouseEvent).clientX, y: (event as MouseEvent).clientY };
  }
  if ('touches' in event && (event as TouchEvent).touches.length > 0) {
    const touch = (event as TouchEvent).touches[0];
    return { x: touch.clientX, y: touch.clientY };
  }
  return null;
};

/** Align the drag overlay with the pointer (corrects offset from transformed ancestors). */
export const snapCenterToCursor: Modifier = ({ activatorEvent, draggingNodeRect, transform }) => {
  if (!draggingNodeRect || !activatorEvent) {
    return transform;
  }
  const coords = getActivatorCoordinates(activatorEvent);
  if (!coords) {
    return transform;
  }
  const offsetX = coords.x - draggingNodeRect.left - draggingNodeRect.width / 2;
  const offsetY = coords.y - draggingNodeRect.top - draggingNodeRect.height / 2;
  return {
    ...transform,
    x: transform.x + offsetX,
    y: transform.y + offsetY,
  };
};

/** Re-align collision box when the overlay uses snapCenterToCursor. */
export const groupingPointerCollision: CollisionDetection = (args) => {
  if (!args.pointerCoordinates) {
    return rectIntersection(args);
  }
  const { x, y } = args.pointerCoordinates;
  const { width, height } = args.collisionRect;
  return rectIntersection({
    ...args,
    collisionRect: {
      width,
      height,
      top: y - height / 2,
      bottom: y + height / 2,
      left: x - width / 2,
      right: x + width / 2,
    },
  });
};
