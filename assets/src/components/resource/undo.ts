import * as Immutable from 'immutable';

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
