import {
  FETCH_MEDIA_PAGE,
  FetchMediaPageAction,
  RESET_MEDIA,
  ResetMediaAction,
  RECEIVE_MEDIA_PAGE,
  ReceiveMediaPageAction,
  SIDELOAD_DATA,
  SideloadDataAction,
  LOAD_MEDIA_REFS,
  LoadMediaReferencesAction,
} from 'actions/media';

import { OrderedMediaLibrary } from 'components/media/OrderedMediaLibrary';

export type ActionTypes =
  | FetchMediaPageAction
  | ResetMediaAction
  | ReceiveMediaPageAction
  | SideloadDataAction
  | LoadMediaReferencesAction;

export type MediaState = OrderedMediaLibrary;

export function initMediaState(json: any) {
  return new OrderedMediaLibrary();
}

const initialState = new OrderedMediaLibrary();

export const media = (state: MediaState = initialState, action: ActionTypes): MediaState => {
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
