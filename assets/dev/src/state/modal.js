import { modalActions } from '../actions/modal';
import * as Immutable from 'immutable';
const defaultState = Immutable.Stack();
export function initModalState(json) {
    return Immutable.Stack();
}
export function modal(state = defaultState, action) {
    switch (action.type) {
        case modalActions.DISMISS_MODAL:
            return state.pop();
        case modalActions.DISPLAY_MODAL:
            return state.push(action.component);
        default:
            return state;
    }
}
//# sourceMappingURL=modal.js.map