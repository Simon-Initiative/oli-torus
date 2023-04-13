import { connect } from 'react-redux';
import { Dispatch, State } from 'state';
import { Maybe } from 'tsmonad';
import { fetchCourseMediaNextPage, fetchMediaItemByPath, resetMedia } from 'actions/media';
import { MediaItem, MediaLibraryOption } from 'types/media';
import { OrderedMediaLibrary } from '../OrderedMediaLibrary';
import { MediaManager, SELECTION_TYPES } from './MediaManager';

export { MIMETYPE_FILTERS, SELECTION_TYPES } from './MediaManager';

interface StateProps {
  media: OrderedMediaLibrary;
}

interface DispatchProps {
  onLoadCourseMediaNextPage: (
    projectSlug: string,
    mimeFilter: string[] | undefined,
    searchText: string,
    orderBy: string,
    order: string,
  ) => void;
  onResetMedia: () => void;
  onLoadMediaItemByPath: (projectSlug: string, path: string) => Promise<Maybe<MediaItem>>;
}

interface OwnProps {
  disabled?: boolean;
  className?: string;
  projectSlug: string;
  mimeFilter?: string[] | undefined;
  selectionType: SELECTION_TYPES;
  initialSelectionPaths?: string[];
  onSelectionChange: (selection: MediaItem[]) => void;
}

const mapStateToProps = (state: State, _ownProps: OwnProps): StateProps => {
  return {
    media: state.media,
  };
};

const mapDispatchToProps = (dispatch: Dispatch, _ownProps: OwnProps): DispatchProps => {
  return {
    onLoadCourseMediaNextPage: (projectSlug, mimeFilter, searchText, orderBy, order) => {
      return dispatch(
        fetchCourseMediaNextPage(projectSlug, mimeFilter, searchText, orderBy, order) as any,
      );
    },
    onResetMedia: () => {
      dispatch(resetMedia());
    },
    onLoadMediaItemByPath: (projectSlug: string, path: string) =>
      dispatch(fetchMediaItemByPath(projectSlug, path) as any),
  };
};

export const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(MediaManager);

export { controller as MediaManager };
