import { connect } from 'react-redux';
import { fetchCourseMediaNextPage, resetMedia, fetchMediaItemByPath } from 'actions/media';
import { MediaManager } from './MediaManager';
export { MIMETYPE_FILTERS, SELECTION_TYPES } from './MediaManager';
const mapStateToProps = (state, _ownProps) => {
    return {
        media: state.media,
    };
};
const mapDispatchToProps = (dispatch, _ownProps) => {
    return {
        onLoadCourseMediaNextPage: (projectSlug, mimeFilter, searchText, orderBy, order) => {
            return dispatch(fetchCourseMediaNextPage(projectSlug, mimeFilter, searchText, orderBy, order));
        },
        onResetMedia: () => {
            dispatch(resetMedia());
        },
        onLoadMediaItemByPath: (projectSlug, path) => dispatch(fetchMediaItemByPath(projectSlug, path)),
    };
};
export const controller = connect(mapStateToProps, mapDispatchToProps)(MediaManager);
export { controller as MediaManager };
//# sourceMappingURL=MediaManager.controller.js.map