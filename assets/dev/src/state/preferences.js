var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { Record } from 'immutable';
import { Maybe } from 'tsmonad';
import { valueOr } from 'utils/common';
import { fetchPreferences as fetchPreferencesRequest, updatePreferences as updatePreferencesRequest, } from 'data/persistence/preferences';
export const UPDATE_PREFERENCES = 'preferences/UPDATE_PREFERENCES';
export const updatePreferences = (preferences) => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    // dispatch any async actions such as AJAX calls, etc...
    const previousState = getState();
    try {
        // optimistically update the state
        dispatch({
            type: UPDATE_PREFERENCES,
            preferences,
        });
        yield updatePreferencesRequest(preferences);
    }
    catch (e) {
        console.error(e);
        // reset to original state before the error
        dispatch({
            type: UPDATE_PREFERENCES,
            preferences: previousState.preferences.preferences,
        });
    }
});
export const LOAD_PREFERENCES = 'preferences/LOAD_PREFERENCES';
export const loadPreferences = () => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    // dispatch any async actions such as AJAX calls, etc...
    const preferences = yield fetchPreferencesRequest();
    dispatch({
        type: LOAD_PREFERENCES,
        preferences,
    });
});
const defaults = (params = {}) => ({
    preferences: valueOr(params.preferences, Maybe.nothing()),
});
export class PreferencesState extends Record(defaults()) {
    constructor(params) {
        super(defaults(params));
    }
    with(values) {
        return this.merge(values);
    }
}
//// REDUCER ////
export const initialState = new PreferencesState();
export const preferences = (state = initialState, action) => {
    switch (action.type) {
        case UPDATE_PREFERENCES:
            return state.with({
                preferences: Maybe.maybe(action.preferences),
            });
        case LOAD_PREFERENCES:
            return state.with({
                preferences: Maybe.maybe(action.preferences),
            });
        default:
            return state;
    }
};
//# sourceMappingURL=preferences.js.map