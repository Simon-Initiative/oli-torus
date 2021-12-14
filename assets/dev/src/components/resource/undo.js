import * as Immutable from 'immutable';
import isHotkey from 'is-hotkey';
export function init(current) {
    return {
        current,
        undoStack: Immutable.Stack(),
        redoStack: Immutable.Stack(),
    };
}
export function processUndo(state) {
    const next = state.undoStack.peek();
    if (next !== undefined) {
        const undoStack = state.undoStack.pop();
        const redoStack = state.redoStack.push(state.current);
        return { current: next, undoStack, redoStack };
    }
    return state;
}
export function processRedo(state) {
    const next = state.redoStack.peek();
    if (next !== undefined) {
        const undoStack = state.undoStack.push(state.current);
        const redoStack = state.redoStack.pop();
        return { current: next, undoStack, redoStack };
    }
    return state;
}
export function processUpdate(state, update) {
    return {
        current: Object.assign({}, state.current, update),
        undoStack: state.undoStack.push(state.current),
        redoStack: state.redoStack,
    };
}
export function registerUndoRedoHotkeys(onUndo, onRedo) {
    // register hotkeys
    const isUndoHotkey = isHotkey('mod+z');
    const isRedoHotkey = isHotkey('mod+shift+z');
    return window.addEventListener('keydown', (e) => {
        if (isUndoHotkey(e)) {
            onUndo();
        }
        else if (isRedoHotkey(e)) {
            onRedo();
        }
    });
}
export function unregisterUndoRedoHotkeys(listener) {
    window.removeEventListener('keydown', listener);
}
//# sourceMappingURL=undo.js.map