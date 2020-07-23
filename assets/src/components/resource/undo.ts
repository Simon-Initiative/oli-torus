import * as Immutable from 'immutable';
import isHotkey from 'is-hotkey';

export interface UndoableState<T> {
  current: T;
  undoStack: Immutable.Stack<T>;
  redoStack: Immutable.Stack<T>;
}

export function init<T>(current: T): UndoableState<T> {
  return {
    current,
    undoStack: Immutable.Stack<T>(),
    redoStack: Immutable.Stack<T>(),
  };
}

export function processUndo<T>(state: UndoableState<T>): UndoableState<T> {

  const next = state.undoStack.peek();

  if (next !== undefined) {
    const undoStack = state.undoStack.pop();
    const redoStack = state.redoStack.push(state.current);
    return { current: next, undoStack, redoStack };
  }

  return state;
}

export function processRedo<T>(state: UndoableState<T>): UndoableState<T> {

  const next = state.redoStack.peek();

  if (next !== undefined) {
    const undoStack = state.undoStack.push(state.current);
    const redoStack = state.redoStack.pop();
    return { current: next, undoStack, redoStack };
  }

  return state;
}

export function processUpdate<T>(
  state: UndoableState<T>, update: Partial<T>): UndoableState<T> {
  return {
    current: Object.assign({}, state.current, update),
    undoStack: state.undoStack.push(state.current),
    redoStack: state.redoStack,
  };
}


export function registerUndoRedoHotkeys(onUndo: () => void, onRedo: () => void) {
  // register hotkeys
  const isUndoHotkey = isHotkey('mod+z');
  const isRedoHotkey = isHotkey('mod+shift+z');

  return window.addEventListener('keydown', (e: KeyboardEvent) => {
    if (isUndoHotkey(e)) {
      onUndo();
    } else if (isRedoHotkey(e)) {
      onRedo();
    }
  });
}

export function unregisterUndoRedoHotkeys(listener: any) {
  window.removeEventListener('keydown', listener);
}
