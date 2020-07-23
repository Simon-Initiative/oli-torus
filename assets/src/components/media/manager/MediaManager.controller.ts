import { connect } from 'react-redux';
import { Maybe } from 'tsmonad';
import { State, Dispatch } from 'state';
import { fetchCourseMediaNextPage, resetMedia, fetchMediaItemByPath } from 'actions/media';
import { OrderedMediaLibrary } from '../OrderedMediaLibrary';
import { Media, MediaItem } from 'types/media';
import { MediaManager, SELECTION_TYPES } from './MediaManager';

export { MIMETYPE_FILTERS, SELECTION_TYPES } from './MediaManager';

interface StateProps {
  media: OrderedMediaLibrary;
}

interface DispatchProps {
  onLoadCourseMediaNextPage: (projectSlug: string,
    mimeFilter: string[] | undefined, searchText: string,
    orderBy: string, order: string) => void;
  onResetMedia: () => void;
  onLoadMediaItemByPath: (projectSlug: string, path: string) => Promise<Maybe<MediaItem>>;
}

interface OwnProps {
  className?: string;
  model: Media;
  projectSlug: string;
  mimeFilter?: string[] | undefined;
  selectionType: SELECTION_TYPES;
  initialSelectionPaths?: string[];
  onEdit: (updated: Media) => void;
  onSelectionChange: (selection: MediaItem[]) => void;
}

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  return {
    media: state.media,
  };
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {
    onLoadCourseMediaNextPage: (projectSlug, mimeFilter, searchText, orderBy, order) => {
      return dispatch(fetchCourseMediaNextPage(
        projectSlug, mimeFilter, searchText, orderBy, order) as any);
    },
    onResetMedia: () => {
      dispatch(resetMedia());
    },
    onLoadMediaItemByPath: (projectSlug: string, path: string) => (
      dispatch(fetchMediaItemByPath(projectSlug, path) as any)
    ),
  };
};

export const controller = connect<StateProps, DispatchProps, OwnProps>
  (mapStateToProps, mapDispatchToProps)(MediaManager);

export { controller as MediaManager };
