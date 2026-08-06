// Phoenix LiveView hooks that implements drag and drop

type ElementHook = {
  el: HTMLElement;
};

type DragDropHook = ElementHook & {
  pushEvent: (event: string, payload?: unknown) => void;
};

interface ScopedReorderPayload {
  itemId: string;
  scope: string;
}

let pendingKeyboardReorderFocusKey: string | null = null;
let pendingKeyboardReorderCleanupTimer: ReturnType<typeof setTimeout> | null = null;

const keyboardReorderKey = (element: HTMLElement) => {
  return element.getAttribute('data-keyboard-reorder-key');
};

const keyboardReorderDetails = (element: HTMLElement) => {
  const position = Number.parseInt(element.getAttribute('data-reorder-position') ?? '', 10);
  const count = Number.parseInt(element.getAttribute('data-reorder-count') ?? '', 10);
  return { position, count };
};

const restoreKeyboardReorderFocus = (element: HTMLElement) => {
  const key = keyboardReorderKey(element);

  if (!key || key !== pendingKeyboardReorderFocusKey) {
    return;
  }

  if (pendingKeyboardReorderCleanupTimer) {
    clearTimeout(pendingKeyboardReorderCleanupTimer);
    pendingKeyboardReorderCleanupTimer = null;
  }

  const { position, count } = keyboardReorderDetails(element);
  const statusId = element.getAttribute('data-keyboard-reorder-status-id');
  const status = statusId ? document.getElementById(statusId) : null;
  const label = element.getAttribute('data-keyboard-reorder-label') || 'Item';

  if (status) {
    status.textContent = `${label} moved to position ${position + 1} of ${count}.`;
  }

  pendingKeyboardReorderFocusKey = null;
  element.focus();
};

let activeReorderScope: string | null = null;
let scopedDragVisibilityTimer: ReturnType<typeof setTimeout> | null = null;

const scopedDropTargets = (scope: string): HTMLElement[] =>
  Array.from(document.querySelectorAll<HTMLElement>('.alternatives-option-drop-target')).filter(
    (target) => target.getAttribute('data-reorder-scope') === scope,
  );

const redundantScopedDropTargets = (element: HTMLElement): HTMLElement[] => {
  const resourceId = element.getAttribute('data-reorder-resource-id');
  const sourceIndex = Number.parseInt(element.getAttribute('data-drag-index') ?? '', 10);

  if (!resourceId || Number.isNaN(sourceIndex)) {
    return [];
  }

  return [sourceIndex + 1]
    .map((index) => document.getElementById(`option-drop-target-${resourceId}-${index}`))
    .filter((target): target is HTMLElement => target !== null);
};

const setScopedDragVisibility = (element: HTMLElement, hidden: boolean) => {
  element.classList.toggle('hidden', hidden);
  redundantScopedDropTargets(element).forEach((target) =>
    target.classList.toggle('hidden', hidden),
  );
};

const setScopedDropTargetsActive = (scope: string | null, active: boolean) => {
  if (scope) {
    scopedDropTargets(scope).forEach((target) => target.classList.toggle('drag-active', active));
  }
};

export const parseScopedReorderPayload = (payload: string): ScopedReorderPayload | null => {
  try {
    const parsed: unknown = JSON.parse(payload);

    if (typeof parsed === 'object' && parsed !== null) {
      const record = parsed as Record<string, unknown>;

      if (typeof record.itemId === 'string' && typeof record.scope === 'string') {
        return { itemId: record.itemId, scope: record.scope };
      }
    }

    return null;
  } catch {
    return null;
  }
};

const acceptsDrop = (element: HTMLElement): boolean => {
  const targetScope = element.getAttribute('data-reorder-scope');

  if (!targetScope) {
    return activeReorderScope === null;
  }

  return activeReorderScope === targetScope;
};

export const DropTarget = {
  mounted(this: DragDropHook) {
    this.el.addEventListener('dragenter', (e: any) => {
      if (acceptsDrop(this.el)) {
        this.el.classList.add('hovered');
      }
    });
    this.el.addEventListener('dragleave', (e: any) => {
      this.el.classList.remove('hovered');
    });
    this.el.addEventListener('drop', (e: any) => {
      e.preventDefault();
      this.el.classList.remove('hovered');

      const scopedPayload = e.dataTransfer.getData('application/x-oli-reorder');

      if (scopedPayload) {
        const parsedPayload = parseScopedReorderPayload(scopedPayload);
        const targetScope = this.el.getAttribute('data-reorder-scope');

        if (parsedPayload && parsedPayload.scope === targetScope) {
          e.stopPropagation();

          const eventName = this.el.getAttribute('data-reorder-event');
          const resourceId = this.el.getAttribute('data-reorder-resource-id');
          const dropIndex = this.el.getAttribute('data-drop-index');

          if (eventName && resourceId && dropIndex) {
            this.pushEvent(eventName, {
              resourceId,
              optionId: parsedPayload.itemId,
              dropIndex,
            });
          }
        }

        return;
      }

      // Handle the curriculum/remix index-based drop contract.
      const sourceIndex = e.dataTransfer.getData('text/plain');
      const dropIndex = this.el.getAttribute('data-drop-index');
      this.pushEvent('reorder', { sourceIndex, dropIndex });
    });
    this.el.addEventListener('dragover', (e: any) => {
      if (acceptsDrop(this.el)) {
        e.stopPropagation();
        e.preventDefault();
      }
    });
  },
};

export const DragSource = {
  mounted(this: DragDropHook) {
    restoreKeyboardReorderFocus(this.el);

    this.el.addEventListener('keydown', (event: KeyboardEvent) => {
      const isMoveKey = event.shiftKey && ['ArrowUp', 'ArrowDown'].includes(event.key);

      if (!isMoveKey) {
        return;
      }

      if (event.target !== this.el) {
        event.stopPropagation();
        return;
      }

      event.preventDefault();

      const { position, count } = keyboardReorderDetails(this.el);
      const nextPosition = event.key === 'ArrowUp' ? position - 1 : position + 1;

      if (nextPosition >= 0 && nextPosition < count) {
        pendingKeyboardReorderFocusKey = keyboardReorderKey(this.el);
      } else {
        const statusId = this.el.getAttribute('data-keyboard-reorder-status-id');
        const status = statusId ? document.getElementById(statusId) : null;
        const label = this.el.getAttribute('data-keyboard-reorder-label') || 'Item';

        if (status) {
          status.textContent = `${label} is already ${event.key === 'ArrowUp' ? 'first' : 'last'}.`;
        }
      }
    });

    this.el.addEventListener('blur', (event: FocusEvent) => {
      if (
        event.relatedTarget instanceof HTMLElement &&
        event.relatedTarget !== document.body &&
        keyboardReorderKey(this.el) === pendingKeyboardReorderFocusKey
      ) {
        pendingKeyboardReorderFocusKey = null;
      }
    });

    this.el.addEventListener('dragstart', (e: any) => {
      const dt = e.dataTransfer;
      dt.setData('text/plain', this.el.getAttribute('data-drag-index'));
      dt.effectAllowed = 'move';

      const reorderScope = this.el.getAttribute('data-reorder-scope');
      const reorderItemId = this.el.getAttribute('data-reorder-item-id');
      activeReorderScope = reorderScope && reorderItemId ? reorderScope : null;
      setScopedDropTargetsActive(activeReorderScope, true);

      if (reorderScope && reorderItemId) {
        dt.setData(
          'application/x-oli-reorder',
          JSON.stringify({ itemId: reorderItemId, scope: reorderScope }),
        );

        // Wait until the browser captures its drag image before removing the
        // source row and the two equivalent drop positions around it.
        scopedDragVisibilityTimer = setTimeout(() => {
          setScopedDragVisibility(this.el, true);
          scopedDragVisibilityTimer = null;
        }, 0);
      }

      // Remix entries identify dragged nodes by UUID, while curriculum authoring entries still use slugs.
      const dragId =
        this.el.getAttribute('data-drag-uuid') || this.el.getAttribute('data-drag-slug');

      if (dragId) {
        this.pushEvent('dragstart', dragId);
      }
    });

    this.el.addEventListener('dragend', (e: any) => {
      e.stopPropagation();
      e.preventDefault();
      setScopedDropTargetsActive(activeReorderScope, false);
      activeReorderScope = null;

      if (scopedDragVisibilityTimer) {
        clearTimeout(scopedDragVisibilityTimer);
        scopedDragVisibilityTimer = null;
      }

      setScopedDragVisibility(this.el, false);

      if (this.el.getAttribute('data-drag-uuid') || this.el.getAttribute('data-drag-slug')) {
        this.pushEvent('dragend');
      }
    });
  },

  updated(this: ElementHook) {
    restoreKeyboardReorderFocus(this.el);
  },

  destroyed(this: ElementHook) {
    const key = keyboardReorderKey(this.el);

    if (!key || key !== pendingKeyboardReorderFocusKey) {
      return;
    }

    pendingKeyboardReorderCleanupTimer = setTimeout(() => {
      if (key === pendingKeyboardReorderFocusKey) {
        pendingKeyboardReorderFocusKey = null;
      }

      pendingKeyboardReorderCleanupTimer = null;
    }, 0);
  },
};
