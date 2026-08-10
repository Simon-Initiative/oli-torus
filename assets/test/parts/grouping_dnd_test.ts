import {
  DroppableContainer,
  KeyboardCode,
  KeyboardCoordinateGetter,
  UniqueIdentifier,
} from '@dnd-kit/core';
import {
  GROUPING_KEYBOARD_CODES,
  createGroupingKeyboardCoordinates,
} from '../../src/components/parts/janus-item-bank/grouping-dnd';

const rect = (left: number, top: number, width = 100, height = 100): DOMRect => ({
  left,
  top,
  width,
  height,
  right: left + width,
  bottom: top + height,
  x: left,
  y: top,
  toJSON: () => ({}),
});

class TestDroppableContainers extends Map<UniqueIdentifier, DroppableContainer> {
  get(id: UniqueIdentifier | null | undefined): DroppableContainer | undefined {
    return id == null ? undefined : super.get(id);
  }

  toArray(): DroppableContainer[] {
    return Array.from(this.values());
  }

  getEnabled(): DroppableContainer[] {
    return this.toArray().filter(({ disabled }) => !disabled);
  }

  getNodeFor(id: UniqueIdentifier | null | undefined): HTMLElement | undefined {
    return this.get(id)?.node.current || undefined;
  }
}

const coordinateArgs = (
  overId: string,
  sourceZoneId = 'bank',
): Parameters<KeyboardCoordinateGetter>[1] => {
  const droppableRects = new Map<UniqueIdentifier, DOMRect>([
    ['bank', rect(0, 0)],
    ['category-one', rect(200, 0)],
    ['category-two', rect(400, 0)],
  ]);
  const droppableContainers = new TestDroppableContainers(
    Array.from(droppableRects.entries()).map(([id, droppableRect]) => [
      id,
      {
        id,
        key: id,
        data: { current: undefined },
        disabled: false,
        node: { current: null },
        rect: { current: droppableRect },
      },
    ]),
  );

  return {
    active: 'item-one',
    currentCoordinates: { x: 0, y: 0 },
    context: {
      activatorEvent: null,
      active: {
        id: 'item-one',
        data: {
          current: {
            zoneId: sourceZoneId,
          },
        },
        rect: {
          current: {
            initial: null,
            translated: null,
          },
        },
      },
      activeNode: null,
      collisionRect: rect(0, 0, 20, 20),
      collisions: null,
      draggableNodes: new Map(),
      draggingNode: null,
      draggingNodeRect: null,
      droppableContainers,
      droppableRects,
      over: {
        id: overId,
        rect: droppableRects.get(overId) || rect(0, 0),
        disabled: false,
        data: { current: undefined },
      },
      scrollableAncestors: [],
      scrollAdjustedTranslate: null,
    },
  };
};

describe('Grouping keyboard drag configuration', () => {
  const createCoordinateGetter = (current: string | null) => {
    const keyboardTarget = { current, pending: null };
    return {
      coordinateGetter: createGroupingKeyboardCoordinates(
        ['bank', 'category-one', 'category-two'],
        keyboardTarget,
      ),
      keyboardTarget,
    };
  };

  test('uses Space and Enter to start and end without treating Tab as a drop key', () => {
    expect(GROUPING_KEYBOARD_CODES).toEqual({
      start: [KeyboardCode.Space, KeyboardCode.Enter],
      cancel: [KeyboardCode.Esc],
      end: [KeyboardCode.Space, KeyboardCode.Enter],
    });
    expect(GROUPING_KEYBOARD_CODES.end).not.toContain(KeyboardCode.Tab);
  });

  test.each([
    ['Tab', false, 'bank', { x: 240, y: 40 }],
    ['ArrowRight', false, 'bank', { x: 240, y: 40 }],
    ['ArrowDown', false, 'bank', { x: 240, y: 40 }],
    ['Tab', true, 'category-one', { x: 40, y: 40 }],
    ['ArrowLeft', false, 'category-one', { x: 40, y: 40 }],
    ['ArrowUp', false, 'category-one', { x: 40, y: 40 }],
  ])(
    '%s navigates to the expected adjacent destination',
    (code, shiftKey, overId, expectedCoordinates) => {
      const event = new KeyboardEvent('keydown', { code, shiftKey });
      const { coordinateGetter } = createCoordinateGetter(overId);

      expect(coordinateGetter(event, coordinateArgs(overId))).toEqual(expectedCoordinates);
    },
  );

  test('wraps forward and backward at the destination boundaries', () => {
    const forward = createCoordinateGetter('category-two').coordinateGetter;
    const backward = createCoordinateGetter('bank').coordinateGetter;

    expect(
      forward(new KeyboardEvent('keydown', { code: 'Tab' }), coordinateArgs('category-two')),
    ).toEqual({ x: 40, y: 40 });
    expect(
      backward(
        new KeyboardEvent('keydown', { code: 'Tab', shiftKey: true }),
        coordinateArgs('bank'),
      ),
    ).toEqual({ x: 440, y: 40 });
  });

  test('starts from the item placement instead of a transient collision target', () => {
    const { coordinateGetter, keyboardTarget } = createCoordinateGetter('bank');

    expect(
      coordinateGetter(
        new KeyboardEvent('keydown', { code: 'Tab' }),
        coordinateArgs('category-one', 'bank'),
      ),
    ).toEqual({ x: 240, y: 40 });
    expect(keyboardTarget).toEqual({ current: 'bank', pending: 'category-one' });
  });

  test('does not advance until the pending destination is confirmed', () => {
    const { coordinateGetter, keyboardTarget } = createCoordinateGetter('bank');
    const tabEvent = new KeyboardEvent('keydown', { code: 'Tab' });

    expect(coordinateGetter(tabEvent, coordinateArgs('bank'))).toEqual({ x: 240, y: 40 });
    expect(coordinateGetter(tabEvent, coordinateArgs('bank'))).toEqual({ x: 240, y: 40 });
    expect(keyboardTarget).toEqual({ current: 'bank', pending: 'category-one' });

    expect(coordinateGetter(tabEvent, coordinateArgs('category-one'))).toEqual({
      x: 440,
      y: 40,
    });
    expect(keyboardTarget).toEqual({ current: 'category-one', pending: 'category-two' });
  });
});
