import { List, Map } from 'immutable';
import { State, Dispatch } from 'state/index';
import { ProjectSlug } from 'data/types';
import * as persistence from 'data/persistence/media';
import { Maybe } from 'tsmonad';
import { MediaItem, MediaRef } from 'types/media';
// import * as messageActions from 'actions/messages';
// import * as Messages from 'data/messages/messages';
import guid from 'utils/guid';

const MEDIA_PAGE_SIZE = 60;

export type MediaActions =
  | FetchMediaPageAction
  | ReceiveMediaPageAction
  | ResetMediaAction
  | LoadMediaReferencesAction
  | SideloadDataAction;

export type FETCH_MEDIA_PAGE = 'media/FETCH_MEDIA_PAGE';
export const FETCH_MEDIA_PAGE: FETCH_MEDIA_PAGE = 'media/FETCH_MEDIA_PAGE';

export type FetchMediaPageAction = {
  type: FETCH_MEDIA_PAGE;
  courseId: ProjectSlug;
  reqId: string;
};

export const fetchMediaPage = (courseId: ProjectSlug, reqId: string): FetchMediaPageAction => ({
  type: FETCH_MEDIA_PAGE,
  courseId,
  reqId,
});

export type RESET_MEDIA = 'media/RESET_MEDIA';
export const RESET_MEDIA: RESET_MEDIA = 'media/RESET_MEDIA';

export type ResetMediaAction = {
  type: RESET_MEDIA;
};

export const resetMedia = (): ResetMediaAction => ({
  type: RESET_MEDIA,
});

export type RECEIVE_MEDIA_PAGE = 'media/RECEIVE_MEDIA_PAGE';
export const RECEIVE_MEDIA_PAGE: RECEIVE_MEDIA_PAGE = 'media/RECEIVE_MEDIA_PAGE';

export type ReceiveMediaPageAction = {
  type: RECEIVE_MEDIA_PAGE;
  courseId: ProjectSlug;
  items: List<MediaItem>;
  totalItems: number;
};

export const receiveMediaPage = (
  courseId: ProjectSlug,
  items: List<MediaItem>,
  totalItems: number,
): ReceiveMediaPageAction => ({
  type: RECEIVE_MEDIA_PAGE,
  courseId,
  items,
  totalItems,
});

export type SIDELOAD_DATA = 'media/SIDELOAD_DATA';
export const SIDELOAD_DATA: SIDELOAD_DATA = 'media/SIDELOAD_DATA';

export type SideloadDataAction = {
  type: SIDELOAD_DATA;
  courseId: ProjectSlug;
  data: Map<string, MediaItem>;
};

export const sideloadData = (
  courseId: ProjectSlug,
  data: Map<string, MediaItem>,
): SideloadDataAction => ({
  type: SIDELOAD_DATA,
  courseId,
  data,
});

export type LOAD_MEDIA_REFS = 'media/LOAD_MEDIA_REFS';
export const LOAD_MEDIA_REFS: LOAD_MEDIA_REFS = 'media/LOAD_MEDIA_REFS';

export type LoadMediaReferencesAction = {
  type: LOAD_MEDIA_REFS;
  courseId: ProjectSlug;
  references: Map<string, List<MediaRef>>;
};

export const loadMediaReferences = (
  courseId: ProjectSlug,
  references: Map<string, List<MediaRef>>,
): LoadMediaReferencesAction => ({
  type: LOAD_MEDIA_REFS,
  courseId,
  references,
});

export const fetchCourseMedia = (
  courseId: ProjectSlug,
  offset?: number,
  limit?: number,
  mimeFilter?: string[],
  searchText?: string,
  orderBy?: string,
  order?: string,
) => (dispatch: Dispatch, getState: () => State): Promise<Maybe<List<MediaItem>>> => {
  const reqId = guid();
  dispatch(fetchMediaPage(courseId, reqId));

  const handleError = (err: any) => {
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
        const items = List<MediaItem>(response.results);

        // check if the response is for the latest request
        if ((getState() as any).media.lastReqId === reqId) {
          // request is latest, update state
          dispatch(receiveMediaPage(courseId, items, response.totalResults));
          // dispatch(fetchMediaReferences(courseId) as any);
        }

        return Maybe.just<List<MediaItem>>(items);
      }
      return Maybe.nothing<List<MediaItem>>();
    })
    .catch((err) => {
      return Maybe.nothing<List<MediaItem>>();
    });
};

export const fetchCourseMediaNextPage = (
  courseId: ProjectSlug,
  mimeFilter?: string[],
  searchText?: string,
  orderBy?: string,
  order?: string,
) => (dispatch: Dispatch, getState: () => State): Promise<Maybe<List<MediaItem>>> => {
  const limit = MEDIA_PAGE_SIZE;
  const offset = (getState() as any).media.items.size || 0;

  return dispatch(
    fetchCourseMedia(courseId, offset, limit, mimeFilter, searchText, orderBy, order) as any,
  );
};

export const fetchMediaItemByPath = (courseId: ProjectSlug, url: string) => (
  dispatch: Dispatch,
  getState: () => State,
): Promise<Maybe<MediaItem>> => {
  const limit = 1;
  const offset = 0;

  return persistence.fetchMedia(courseId, offset, limit, undefined, url).then((response) => {
    if (response.type === 'success') {
      const data = Map<string, MediaItem>(response.results.map((item) => [item.guid, item]));
      return Maybe.just<MediaItem>(data.first() as any);
    }
    return Maybe.nothing<MediaItem>();
  });
};
