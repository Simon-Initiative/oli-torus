import { combineReducers } from 'redux';
import { media, initMediaState } from 'state/media';
import { modal, initModalState } from 'state/modal';
import { PreferencesState, preferences } from 'state/preferences';
export default combineReducers({
    media,
    modal,
    preferences,
});
export function initState(json = {}) {
    return {
        media: initMediaState(json),
        modal: initModalState(json),
        preferences: new PreferencesState(json),
    };
}
//# sourceMappingURL=index.js.map