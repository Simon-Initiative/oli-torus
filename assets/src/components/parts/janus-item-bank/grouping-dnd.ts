import {
  CollisionDetection,
  KeyboardCode,
  KeyboardCodes,
  KeyboardCoordinateGetter,
  Modifier,
  rectIntersection,
} from '@dnd-kit/core';

export const GROUPING_KEYBOARD_CODES: KeyboardCodes = {
  start: [KeyboardCode.Space, KeyboardCode.Enter],
  cancel: [KeyboardCode.Esc],
  end: [KeyboardCode.Space, KeyboardCode.Enter],
};

export interface GroupingKeyboardTarget {
  current: string | null;
  pending: string | null;
}

export const confirmGroupingKeyboardTarget = (
  keyboardTarget: GroupingKeyboardTarget,
  overId: string | null,
): boolean => {
  if (!overId || overId !== keyboardTarget.pending) {
    return false;
  }

  keyboardTarget.current = overId;
  keyboardTarget.pending = null;
  return true;
};

const keyboardNavigationDirection = (event: KeyboardEvent): number => {
  if (
    event.code === KeyboardCode.Left ||
    event.code === KeyboardCode.Up ||
    (event.code === KeyboardCode.Tab && event.shiftKey)
  ) {
    return -1;
  }
  if (
    event.code === KeyboardCode.Right ||
    event.code === KeyboardCode.Down ||
    event.code === KeyboardCode.Tab
  ) {
    return 1;
  }
  return 0;
};

/**
 * Moves the keyboard collision rectangle between Grouping destinations in model order.
 * Centering the rectangle in the target avoids layout-dependent arrow increments.
 */
export const createGroupingKeyboardCoordinates =
  (zoneIds: string[], keyboardTarget: GroupingKeyboardTarget): KeyboardCoordinateGetter =>
  (event, { context }) => {
    const direction = keyboardNavigationDirection(event);
    if (direction === 0) {
      return undefined;
    }

    const availableZoneIds = zoneIds.filter((zoneId) => {
      const container = context.droppableContainers.get(zoneId);
      return container && !container.disabled && context.droppableRects.has(zoneId);
    });
    if (availableZoneIds.length === 0) {
      return undefined;
    }

    const overZoneId = context.over ? `${context.over.id}` : null;
    if (overZoneId && availableZoneIds.includes(overZoneId)) {
      confirmGroupingKeyboardTarget(keyboardTarget, overZoneId);
    }

    const sourceZoneId = `${context.active?.data.current?.zoneId || availableZoneIds[0]}`;
    const currentZoneId = keyboardTarget.current || sourceZoneId;
    const currentIndex = Math.max(availableZoneIds.indexOf(currentZoneId), 0);
    const targetIndex =
      (currentIndex + direction + availableZoneIds.length) % availableZoneIds.length;
    const targetZoneId = availableZoneIds[targetIndex];
    const targetRect = context.droppableRects.get(targetZoneId);
    if (!targetRect) {
      return undefined;
    }

    keyboardTarget.pending = targetZoneId;
    const collisionWidth = context.collisionRect?.width || 0;
    const collisionHeight = context.collisionRect?.height || 0;
    return {
      x: targetRect.left + targetRect.width / 2 - collisionWidth / 2,
      y: targetRect.top + targetRect.height / 2 - collisionHeight / 2,
    };
  };

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
