import { List, Map } from 'immutable';
import * as persistence from 'data/persistence/media';
import { Maybe } from 'tsmonad';
import guid from 'utils/guid';
const MEDIA_PAGE_SIZE = 60;
export const FETCH_MEDIA_PAGE = 'media/FETCH_MEDIA_PAGE';
export const fetchMediaPage = (courseId, reqId) => ({
    type: FETCH_MEDIA_PAGE,
    courseId,
    reqId,
});
export const RESET_MEDIA = 'media/RESET_MEDIA';
export const resetMedia = () => ({
    type: RESET_MEDIA,
});
export const RECEIVE_MEDIA_PAGE = 'media/RECEIVE_MEDIA_PAGE';
export const receiveMediaPage = (courseId, items, totalItems) => ({
    type: RECEIVE_MEDIA_PAGE,
    courseId,
    items,
    totalItems,
});
export const SIDELOAD_DATA = 'media/SIDELOAD_DATA';
export const sideloadData = (courseId, data) => ({
    type: SIDELOAD_DATA,
    courseId,
    data,
});
export const LOAD_MEDIA_REFS = 'media/LOAD_MEDIA_REFS';
export const loadMediaReferences = (courseId, references) => ({
    type: LOAD_MEDIA_REFS,
    courseId,
    references,
});
export const fetchCourseMedia = (courseId, offset, limit, mimeFilter, searchText, orderBy, order) => (dispatch, getState) => {
    const reqId = guid();
    dispatch(fetchMediaPage(courseId, reqId));
    const handleError = (err) => {
        /*
          const content = new Messages.TitledContent().with({
            title: 'Failed to load media',
            message: 'There was a problem loading media for this course. '
              + 'Please check your internet connection and try again.',
          });
  
          const failedMessage = new Messages.Message().with({
            content,
            scope: Messages.Scope.Resource,
            severity: Messages.Severity.Error,
            canUserDismiss: true,
          });
  
          dispatch(messageActions.showMessage(failedMessage));
          */
    };
    return persistence
        .fetchMedia(courseId, offset, limit, mimeFilter, undefined, searchText, orderBy, order)
        .then((response) => {
        if (response.type === 'success') {
            const items = List(response.results);
            // check if the response is for the latest request
            if (getState().media.lastReqId === reqId) {
                // request is latest, update state
                dispatch(receiveMediaPage(courseId, items, response.totalResults));
                // dispatch(fetchMediaReferences(courseId) as any);
            }
            return Maybe.just(items);
        }
        return Maybe.nothing();
    })
        .catch(() => {
        return Maybe.nothing();
    });
};
export const fetchCourseMediaNextPage = (courseId, mimeFilter, searchText, orderBy, order) => (dispatch, getState) => {
    const limit = MEDIA_PAGE_SIZE;
    const offset = getState().media.items.size || 0;
    return dispatch(fetchCourseMedia(courseId, offset, limit, mimeFilter, searchText, orderBy, order));
};
export const fetchMediaItemByPath = (courseId, url) => (dispatch, getState) => {
    const limit = 1;
    const offset = 0;
    return persistence.fetchMedia(courseId, offset, limit, undefined, url).then((response) => {
        if (response.type === 'success') {
            const data = Map(response.results.map((item) => [item.guid, item]));
            return Maybe.just(data.first());
        }
        return Maybe.nothing();
    });
};
//# sourceMappingURL=media.js.map