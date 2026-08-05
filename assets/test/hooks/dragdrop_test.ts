import { DragSource, DropTarget, parseScopedReorderPayload } from 'hooks/dragdrop';

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

const keyboardReorderItem = (position = 1, count = 3, key = 'alternatives:123:option-a') => {
  const item = document.createElement('li');
  const status = document.createElement('span');
  status.id = `${key.replace(/:/g, '-')}-status`;
  item.tabIndex = 0;
  item.dataset.keyboardReorderKey = key;
  item.dataset.keyboardReorderStatusId = status.id;
  item.dataset.keyboardReorderLabel = 'Item';
  item.dataset.reorderPosition = String(position);
  item.dataset.reorderCount = String(count);
  document.body.append(item, status);

  return item;
};

const pressKey = (element: HTMLElement, key: string, shiftKey = false) => {
  const event = new KeyboardEvent('keydown', {
    key,
    shiftKey,
    bubbles: true,
    cancelable: true,
  });
  element.dispatchEvent(event);
  return event;
};

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

describe('DragSource keyboard reordering', () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it('leaves movement server-side while marking Shift+Arrow for focus restoration', () => {
    const item = keyboardReorderItem();
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: item, pushEvent });

    const event = pressKey(item, 'ArrowDown', true);

    expect(event.defaultPrevented).toBe(true);
    expect(pushEvent).not.toHaveBeenCalled();
  });

  it('restores focus to a later list item after an in-place server patch', () => {
    const first = keyboardReorderItem(0, 2, 'alternatives:123:option-a');
    const second = keyboardReorderItem(0, 3, 'alternatives:456:option-b');
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: first, pushEvent });
    DragSource.mounted.call({ el: second, pushEvent });

    second.focus();
    pressKey(second, 'ArrowDown', true);
    second.blur();
    second.dataset.reorderPosition = '1';
    DragSource.updated.call({ el: second });

    expect(second).toHaveFocus();
    expect(document.getElementById(second.dataset.keyboardReorderStatusId!)).toHaveTextContent(
      'Item moved to position 2 of 3.',
    );

    pressKey(second, 'ArrowDown', true);
    second.blur();
    second.dataset.reorderPosition = '2';
    DragSource.updated.call({ el: second });

    expect(second).toHaveFocus();
  });

  it('restores focus when LiveView replaces the moved item', () => {
    jest.useFakeTimers();
    const original = keyboardReorderItem(0, 2, 'curriculum:page-1');
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: original, pushEvent });
    original.focus();
    pressKey(original, 'ArrowDown', true);
    DragSource.destroyed.call({ el: original });
    original.remove();

    const replacement = keyboardReorderItem(1, 2, 'curriculum:page-1');
    DragSource.mounted.call({ el: replacement, pushEvent });
    jest.runOnlyPendingTimers();

    expect(replacement).toHaveFocus();
    jest.useRealTimers();
  });

  it('does not mark an out-of-bounds move for focus restoration', () => {
    const item = keyboardReorderItem(0, 2);
    const nextControl = document.createElement('button');
    document.body.append(nextControl);
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: item, pushEvent });

    item.focus();
    pressKey(item, 'ArrowUp', true);
    nextControl.focus();
    DragSource.updated.call({ el: item });

    expect(nextControl).toHaveFocus();
    expect(document.getElementById(item.dataset.keyboardReorderStatusId!)).toHaveTextContent(
      'Item is already first.',
    );
  });

  it('does not restore focus after the user intentionally moves to another control', () => {
    const item = keyboardReorderItem();
    const nextControl = document.createElement('button');
    document.body.appendChild(nextControl);
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: item, pushEvent });

    item.focus();
    pressKey(item, 'ArrowDown', true);
    nextControl.focus();
    DragSource.updated.call({ el: item });

    expect(nextControl).toHaveFocus();
  });

  it('stops Shift+Arrow events from nested action controls', () => {
    const item = keyboardReorderItem();
    const action = document.createElement('button');
    item.append(action);
    const pushEvent = jest.fn();
    DragSource.mounted.call({ el: item, pushEvent });
    const parentListener = jest.fn();
    document.body.addEventListener('keydown', parentListener);

    pressKey(action, 'ArrowDown', true);

    expect(parentListener).not.toHaveBeenCalled();
  });
});
