import * as Immutable from 'immutable';
import { ResourceContent } from 'data/content/resource';

export type ContentList = Immutable.List<ResourceContent>;

export type UndoState = {
  current: ContentList,
  undoStack: Immutable.Stack<ContentList>,
  redoStack: Immutable.Stack<ContentList>,
};

export type UndoAction = Undo | Redo | Update;

export interface Undo {
  type: 'undo';
}
export interface Redo {
  type: 'redo';
}
export interface Update {
  type: 'update';
  current: ContentList;
}

export const undo = () => ({ type: 'undo' } as Undo);
export const redo = () => ({ type: 'redo' } as Redo);
export const update = (current: any) => ({ type: 'update', current } as Update);


function processUndo(state: UndoState): UndoState {

  const current = state.undoStack.peek();

  if (current !== undefined) {
    const undoStack = state.undoStack.pop();
    const redoStack = state.redoStack.push(current);
    return { current, undoStack, redoStack };
  }

  return state;
}

function processRedo(state: UndoState): UndoState {

  const current = state.redoStack.peek();

  if (current !== undefined) {
    const undoStack = state.undoStack.push(current);
    const redoStack = state.redoStack.pop();
    return { current, undoStack, redoStack };
  }

  return state;
}

function processUpdate(state: UndoState, current: ContentList): UndoState {
  return {
    current,
    undoStack: state.undoStack.push(state.current),
    redoStack: state.redoStack,
  };
}

export function undoReducer(state : UndoState, action : UndoAction) {
  switch (action.type) {
    case 'undo':
      return processUndo(state);
    case 'redo':
      return processRedo(state);
    case 'update':
      return processUpdate(state, action.current);
    default:
      throw new Error();
  }
}
