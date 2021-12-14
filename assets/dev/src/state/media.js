import { FETCH_MEDIA_PAGE, RESET_MEDIA, RECEIVE_MEDIA_PAGE, SIDELOAD_DATA, LOAD_MEDIA_REFS, } from 'actions/media';
import { OrderedMediaLibrary } from 'components/media/OrderedMediaLibrary';
export function initMediaState(json) {
    return new OrderedMediaLibrary();
}
const initialState = new OrderedMediaLibrary();
export const media = (state = initialState, action) => {
    switch (action.type) {
        case FETCH_MEDIA_PAGE: {
            const { reqId } = action;
            return state.with({
                isLoading: true,
                lastReqId: reqId,
            });
        }
        case RESET_MEDIA: {
            return state.clearItems();
        }
        case RECEIVE_MEDIA_PAGE: {
            const { items, totalItems } = action;
            return state.load(items, totalItems).with({
                isLoading: false,
            });
        }
        case SIDELOAD_DATA: {
            const { data } = action;
            return state.sideloadData(data);
        }
        case LOAD_MEDIA_REFS: {
            const { references } = action;
            return state.loadReferences(references);
        }
        default:
            return state;
    }
};
//# sourceMappingURL=media.js.map