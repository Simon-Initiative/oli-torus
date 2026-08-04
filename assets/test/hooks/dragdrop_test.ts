import { DragSource, DropTarget, KeyboardReorder, parseScopedReorderPayload } from 'hooks/dragdrop';

const dataTransfer = (values: Record<string, string> = {}) => ({
  effectAllowed: '',
  getData: jest.fn((type: string) => values[type] ?? ''),
  setData: jest.fn((type: string, value: string) => {
    values[type] = value;
  }),
});

const dispatchDragEvent = (
  element: HTMLElement,
  eventName: 'dragstart' | 'dragend' | 'dragenter' | 'dragover' | 'drop',
  transfer: ReturnType<typeof dataTransfer>,
) => {
  const event = new Event(eventName, { bubbles: true, cancelable: true });
  Object.defineProperty(event, 'dataTransfer', { value: transfer });
  element.dispatchEvent(event);
};

const keyboardReorderHandle = (position = 1, count = 3) => {
  const handle = document.createElement('button');
  const liveRegion = document.createElement('span');
  liveRegion.id = 'option-position';
  handle.dataset.reorderEvent = 'reorder_option';
  handle.dataset.reorderResourceId = '123';
  handle.dataset.reorderItemId = 'option-a';
  handle.dataset.reorderPosition = String(position);
  handle.dataset.reorderCount = String(count);
  handle.dataset.reorderLabel = 'Option A';
  handle.dataset.reorderLiveRegionId = liveRegion.id;
  document.body.append(handle, liveRegion);

  return { handle, liveRegion };
};

const pressKey = (element: HTMLElement, key: string) =>
  element.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }));

describe('parseScopedReorderPayload', () => {
  it('accepts a stable item id and reorder scope', () => {
    expect(
      parseScopedReorderPayload(JSON.stringify({ itemId: 'option-a', scope: 'alternatives-123' })),
    ).toEqual({ itemId: 'option-a', scope: 'alternatives-123' });
  });

  it('rejects malformed or incomplete payloads', () => {
    expect(parseScopedReorderPayload('{')).toBeNull();
    expect(parseScopedReorderPayload(JSON.stringify({ itemId: 'option-a' }))).toBeNull();
    expect(
      parseScopedReorderPayload(JSON.stringify({ itemId: 1, scope: 'alternatives-123' })),
    ).toBeNull();
  });
});

describe('shared drag and drop hooks', () => {
  it('routes a scoped drop to its configured event', () => {
    const element = document.createElement('div');
    element.dataset.reorderScope = 'alternatives-123';
    element.dataset.reorderEvent = 'reorder_option';
    element.dataset.reorderResourceId = '123';
    element.dataset.dropIndex = '2';
    const pushEvent = jest.fn();
    DropTarget.mounted.call({ el: element, pushEvent });

    const transfer = dataTransfer({
      'application/x-oli-reorder': JSON.stringify({
        itemId: 'option-a',
        scope: 'alternatives-123',
      }),
    });
    dispatchDragEvent(element, 'drop', transfer);

    expect(pushEvent).toHaveBeenCalledWith('reorder_option', {
      resourceId: '123',
      optionId: 'option-a',
      dropIndex: '2',
    });
  });

  it('ignores a scoped drop from another alternatives group', () => {
    const element = document.createElement('div');
    element.dataset.reorderScope = 'alternatives-456';
    element.dataset.reorderEvent = 'reorder_option';
    element.dataset.reorderResourceId = '456';
    element.dataset.dropIndex = '1';
    const pushEvent = jest.fn();
    DropTarget.mounted.call({ el: element, pushEvent });

    const transfer = dataTransfer({
      'application/x-oli-reorder': JSON.stringify({
        itemId: 'option-a',
        scope: 'alternatives-123',
      }),
    });
    dispatchDragEvent(element, 'drop', transfer);

    expect(pushEvent).not.toHaveBeenCalled();
  });

  it('only shows the drop affordance for a matching scope', () => {
    const element = document.createElement('div');
    element.dataset.reorderScope = 'alternatives-456';
    const pushEvent = jest.fn();
    DropTarget.mounted.call({ el: element, pushEvent });

    const source = document.createElement('button');
    source.dataset.reorderItemId = 'option-a';
    source.dataset.reorderScope = 'alternatives-123';
    DragSource.mounted.call({ el: source, pushEvent });
    const otherGroupTransfer = dataTransfer();
    dispatchDragEvent(source, 'dragstart', otherGroupTransfer);
    dispatchDragEvent(element, 'dragenter', otherGroupTransfer);
    expect(element.classList.contains('hovered')).toBe(false);
    dispatchDragEvent(source, 'dragend', otherGroupTransfer);

    source.dataset.reorderScope = 'alternatives-456';
    const matchingTransfer = dataTransfer();
    dispatchDragEvent(source, 'dragstart', matchingTransfer);
    dispatchDragEvent(element, 'dragenter', matchingTransfer);
    expect(element.classList.contains('hovered')).toBe(true);
    dispatchDragEvent(source, 'dragend', matchingTransfer);
  });

  it('preserves the curriculum index-based drop contract', () => {
    const element = document.createElement('div');
    element.dataset.dropIndex = '3';
    const pushEvent = jest.fn();
    DropTarget.mounted.call({ el: element, pushEvent });

    dispatchDragEvent(element, 'drop', dataTransfer({ 'text/plain': '1' }));

    expect(pushEvent).toHaveBeenCalledWith('reorder', {
      sourceIndex: '1',
      dropIndex: '3',
    });
  });

  it('writes both legacy and scoped drag payloads without emitting curriculum events', () => {
    const element = document.createElement('button');
    element.dataset.dragIndex = '1';
    element.dataset.reorderItemId = 'option-a';
    element.dataset.reorderScope = 'alternatives-123';
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: element, pushEvent });
    const transfer = dataTransfer();

    dispatchDragEvent(element, 'dragstart', transfer);
    dispatchDragEvent(element, 'dragend', transfer);

    expect(transfer.setData).toHaveBeenCalledWith('text/plain', '1');
    expect(transfer.setData).toHaveBeenCalledWith(
      'application/x-oli-reorder',
      JSON.stringify({ itemId: 'option-a', scope: 'alternatives-123' }),
    );
    expect(pushEvent).not.toHaveBeenCalled();
  });

  it('hides the dragged option and only the redundant following drop position', () => {
    jest.useFakeTimers();

    const list = document.createElement('ul');
    const source = document.createElement('li');
    source.id = 'alternatives-option-123-option-a';
    source.dataset.dragIndex = '0';
    source.dataset.reorderItemId = 'option-a';
    source.dataset.reorderResourceId = '123';
    source.dataset.reorderScope = 'alternatives-123';

    const targets = [0, 1, 2, 3].map((index) => {
      const target = document.createElement('li');
      target.id = `option-drop-target-123-${index}`;
      target.classList.add('alternatives-option-drop-target');
      target.dataset.reorderScope = 'alternatives-123';
      list.appendChild(target);
      return target;
    });

    list.insertBefore(source, targets[1]);
    document.body.appendChild(list);

    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: source, pushEvent });
    const transfer = dataTransfer();

    dispatchDragEvent(source, 'dragstart', transfer);
    expect(targets.every((target) => target.classList.contains('drag-active'))).toBe(true);
    jest.runOnlyPendingTimers();

    expect(source.classList.contains('hidden')).toBe(true);
    expect(targets[0].classList.contains('hidden')).toBe(false);
    expect(targets[1].classList.contains('hidden')).toBe(true);
    expect(targets[2].classList.contains('hidden')).toBe(false);
    expect(targets[3].classList.contains('hidden')).toBe(false);

    dispatchDragEvent(source, 'dragend', transfer);

    expect(source.classList.contains('hidden')).toBe(false);
    expect(targets[0].classList.contains('hidden')).toBe(false);
    expect(targets[1].classList.contains('hidden')).toBe(false);
    expect(targets.every((target) => !target.classList.contains('drag-active'))).toBe(true);

    source.dataset.dragIndex = '2';
    dispatchDragEvent(source, 'dragstart', transfer);
    jest.runOnlyPendingTimers();

    expect(targets[1].classList.contains('hidden')).toBe(false);
    expect(targets[2].classList.contains('hidden')).toBe(false);
    expect(targets[3].classList.contains('hidden')).toBe(true);

    dispatchDragEvent(source, 'dragend', transfer);

    list.remove();
    jest.useRealTimers();
  });
});

describe('KeyboardReorder', () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it('picks up, moves, and drops an option while announcing each state', () => {
    const { handle, liveRegion } = keyboardReorderHandle();
    const pushEvent = jest.fn();
    KeyboardReorder.mounted.call({ el: handle, pushEvent });

    pressKey(handle, ' ');
    expect(handle).toHaveAttribute('aria-pressed', 'true');
    expect(liveRegion).toHaveTextContent('Option A picked up. Position 2 of 3.');

    pressKey(handle, 'ArrowUp');
    expect(pushEvent).toHaveBeenCalledWith('reorder_option', {
      resourceId: '123',
      optionId: 'option-a',
      dropIndex: 0,
    });
    expect(handle.dataset.reorderPosition).toBe('0');
    expect(liveRegion).toHaveTextContent('Option A moved to position 1 of 3.');

    pressKey(handle, 'Enter');
    expect(handle).toHaveAttribute('aria-pressed', 'false');
    expect(liveRegion).toHaveTextContent('Option A dropped at position 1 of 3.');
  });

  it('does not move beyond a list boundary', () => {
    const { handle, liveRegion } = keyboardReorderHandle(0, 2);
    const pushEvent = jest.fn();
    KeyboardReorder.mounted.call({ el: handle, pushEvent });

    pressKey(handle, ' ');
    pressKey(handle, 'ArrowUp');

    expect(pushEvent).not.toHaveBeenCalled();
    expect(liveRegion).toHaveTextContent('Option A is already at position 1 of 2.');
  });

  it('cancels keyboard reordering with Escape', () => {
    const { handle, liveRegion } = keyboardReorderHandle();
    const pushEvent = jest.fn();
    KeyboardReorder.mounted.call({ el: handle, pushEvent });

    pressKey(handle, ' ');
    pressKey(handle, 'Escape');
    pressKey(handle, 'ArrowDown');

    expect(handle).toHaveAttribute('aria-pressed', 'false');
    expect(liveRegion).toHaveTextContent('Option A reorder cancelled. Position 2 of 3.');
    expect(pushEvent).not.toHaveBeenCalled();
  });
});
