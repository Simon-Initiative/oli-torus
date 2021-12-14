import * as React from 'react';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { MediaIcon } from './MediaIcon';
import guid from 'utils/guid';
import { convert, stringFormat } from 'utils/format';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { relativeToNow } from 'utils/date';
import { uploadFiles } from './upload';
const PAGELOAD_TRIGGER_MARGIN_PX = 100;
const MAX_NAME_LENGTH = 26;
const PAGE_LOADING_MESSAGE = 'Hang on while we load your items...';
export const MIMETYPE_FILTERS = {
    IMAGE: ['image/jpeg', 'image/png', 'image/tiff', 'image/gif'],
    AUDIO: ['audio/mpeg', 'audio/wav', 'audio/mid', 'audio/mp4'],
    VIDEO: ['video/mp4'],
    HTML: ['text/html'],
    CSV: ['text/csv'],
    ALL: undefined,
};
export var SELECTION_TYPES;
(function (SELECTION_TYPES) {
    SELECTION_TYPES[SELECTION_TYPES["MULTI"] = 0] = "MULTI";
    SELECTION_TYPES[SELECTION_TYPES["SINGLE"] = 1] = "SINGLE";
    SELECTION_TYPES[SELECTION_TYPES["NONE"] = 2] = "NONE";
})(SELECTION_TYPES || (SELECTION_TYPES = {}));
export var LAYOUTS;
(function (LAYOUTS) {
    LAYOUTS[LAYOUTS["GRID"] = 0] = "GRID";
    LAYOUTS[LAYOUTS["LIST"] = 1] = "LIST";
})(LAYOUTS || (LAYOUTS = {}));
const SORT_MAPPINGS = {
    Newest: {
        orderBy: 'dateCreated',
        order: 'desc',
        icon: 'fa fa-calendar',
    },
    Oldest: {
        orderBy: 'dateCreated',
        order: 'asc',
        icon: 'fa fa-calendar',
    },
    'A-Z': {
        orderBy: 'fileName',
        order: 'asc',
        icon: 'fas fa-sort-alpha-up',
    },
    'Z-A': {
        orderBy: 'fileName',
        order: 'desc',
        icon: 'fas fa-sort-alpha-down',
    },
    Type: {
        orderBy: 'mimeType',
        order: 'asc',
        icon: 'far fa-file-image',
    },
    'File Size': {
        orderBy: 'fileSize',
        order: 'asc',
        icon: 'fas fa-sort-numeric-up',
    },
};
const getSortMappingKey = (orderBy, order) => {
    return Object.keys(SORT_MAPPINGS).find((key) => orderBy === SORT_MAPPINGS[key].orderBy &&
        (order === undefined || order === SORT_MAPPINGS[key].order));
};
const popOpenImage = (e) => {
    const link = e.target;
    const w = window.open(link.href, link.target || '_blank', 'menubar=no,toolbar=no,location=no,directories=no,status=no,scrollbars=no,' +
        'resizable=no,dependent,width=800,height=620');
    // allow the link to work if popup is blocked
    return w ? false : true;
};
/**
 * MediaManager React Component
 */
export class MediaManager extends React.PureComponent {
    constructor(props) {
        super(props);
        this.isItemSelectable = (selectionType, item) => selectionType !== SELECTION_TYPES.NONE &&
            (!this.props.mimeFilter || this.props.mimeFilter.includes(item.mimeType));
        this.displayMediaOfType = (mimeFilter) => {
            const { searchText, orderBy, order } = this.state;
            this.props.onResetMedia();
            this.props
                .onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter, searchText, orderBy, order)
                .then((_) => this.setState({ filteredMimeTypes: mimeFilter }));
        };
        this.mimeTypeFilter = (type) => {
            const { filteredMimeTypes } = this.state;
            if (type === MIMETYPE_FILTERS.ALL || filteredMimeTypes === MIMETYPE_FILTERS.ALL) {
                return type === filteredMimeTypes ? 'active' : '';
            }
            const filtersAreSame = (arr1, arr2) => arr1.reduce((acc, curr, i) => (curr === arr2[i] ? acc : false), true);
            return filtersAreSame(filteredMimeTypes, type) ? 'active' : '';
        };
        this.state = {
            selection: Immutable.List(),
            searchText: undefined,
            orderBy: SORT_MAPPINGS.Newest.orderBy,
            order: SORT_MAPPINGS.Newest.order,
            layout: LAYOUTS.GRID,
            showDetails: true,
            error: Maybe.nothing(),
            filteredMimeTypes: props.mimeFilter,
        };
        this.onScroll = this.onScroll.bind(this);
        this.isSelected = this.isSelected.bind(this);
        this.onSelect = this.onSelect.bind(this);
        this.onSearch = this.onSearch.bind(this);
        this.onChangeLayout = this.onChangeLayout.bind(this);
    }
    componentDidMount() {
        const { mimeFilter, initialSelectionPaths, onLoadCourseMediaNextPage, onLoadMediaItemByPath } = this.props;
        const { searchText, orderBy, order } = this.state;
        onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter, searchText, orderBy, order);
        // load initial selection data
        if (initialSelectionPaths) {
            Promise.all(initialSelectionPaths
                .filter((path) => path)
                .map((path) => onLoadMediaItemByPath(this.props.projectSlug, path.replace(/^[./]+/, ''))))
                .then((mediaItems) => {
                this.setState({
                    selection: Immutable.List(mediaItems
                        .map((mi) => mi.caseOf({
                        just: (item) => item.guid,
                        nothing: () => undefined,
                    }))
                        .filter((i) => i)),
                    error: Maybe.nothing(),
                });
            })
                .catch((e) => this.setState({ error: Maybe.just(e.message) }));
        }
    }
    componentWillUnmount() {
        const { onResetMedia } = this.props;
        this.scrollView.removeEventListener('scroll', this.onScroll);
        onResetMedia();
    }
    onUploadClick(id) {
        window.$('#' + id).trigger('click');
    }
    setupScrollListener(scrollView) {
        if (!scrollView) {
            return;
        }
        if (this.scrollView) {
            this.scrollView.removeEventListener('scroll', this.onScroll);
        }
        this.scrollView = scrollView;
        this.scrollView.addEventListener('scroll', this.onScroll);
    }
    onScroll() {
        const { media, onLoadCourseMediaNextPage } = this.props;
        const { searchText, orderBy, order, filteredMimeTypes } = this.state;
        const isLoadingMedia = media.isLoading;
        const allItemsLoaded = media.items.size >= media.totalItems;
        if (allItemsLoaded) {
            this.scrollView.removeEventListener('scroll', this.onScroll);
            return;
        }
        if (!isLoadingMedia &&
            this.scrollView.scrollTop + PAGELOAD_TRIGGER_MARGIN_PX >
                this.scrollContent.offsetHeight - this.scrollView.offsetHeight) {
            onLoadCourseMediaNextPage(this.props.projectSlug, filteredMimeTypes, searchText, orderBy, order);
        }
    }
    onFileUpload(files) {
        const { mimeFilter, onLoadCourseMediaNextPage, onResetMedia } = this.props;
        const { searchText, orderBy, order } = this.state;
        // get a list of the files to upload
        const fileList = [];
        for (let i = 0; i < files.length; i = i + 1) {
            fileList.push(files[i]);
        }
        // sequentially upload files one at a time, then reload the media page
        uploadFiles(this.props.projectSlug, fileList)
            .then((result) => {
            onResetMedia();
            onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter, searchText, orderBy, order)
                // select the most recently uploaded item
                .then((mediaItems) => {
                mediaItems.lift((files) => {
                    if (files.size > 0) {
                        Maybe.maybe(files.find((f) => f.url === (result[0] && result[0].url))).lift((file) => this.onSelect(file.guid));
                    }
                });
            })
                .then(() => this.setState({ error: Maybe.nothing() }));
        })
            .catch((e) => this.setState({ error: Maybe.just(e.message) }));
    }
    onChangeLayout(newLayout) {
        this.setState({
            layout: newLayout,
        });
    }
    isSelected(guid) {
        const { selection } = this.state;
        return selection.includes(guid);
    }
    onSelect(guid) {
        const { media, selectionType, onSelectionChange } = this.props;
        const { selection } = this.state;
        let updatedSelection = selection;
        if (selectionType === SELECTION_TYPES.SINGLE) {
            // clear the current selection
            updatedSelection = Immutable.List([guid]);
        }
        else if (selectionType === SELECTION_TYPES.MULTI) {
            if (this.isSelected(guid)) {
                // unselect item
                updatedSelection = updatedSelection.remove(updatedSelection.findIndex((s) => s === guid));
            }
            else {
                // select item
                updatedSelection = updatedSelection.push(guid);
            }
        }
        else {
            return;
        }
        this.setState({
            selection: updatedSelection,
        });
        const mediaLibrary = media;
        if (mediaLibrary) {
            onSelectionChange(updatedSelection.map((s) => mediaLibrary.getItem(s)).toArray());
            this.props.toggleDisableInsert && this.props.toggleDisableInsert(false);
        }
    }
    onSearch(searchText) {
        const { onLoadCourseMediaNextPage, onResetMedia } = this.props;
        const { orderBy, order, filteredMimeTypes } = this.state;
        onResetMedia();
        onLoadCourseMediaNextPage(this.props.projectSlug, filteredMimeTypes, searchText, orderBy, order);
    }
    onSortChange(sortKey) {
        const { onLoadCourseMediaNextPage, onResetMedia } = this.props;
        const { searchText, filteredMimeTypes } = this.state;
        this.setState({
            orderBy: SORT_MAPPINGS[sortKey].orderBy,
            order: SORT_MAPPINGS[sortKey].order,
        });
        onResetMedia();
        onLoadCourseMediaNextPage(this.props.projectSlug, filteredMimeTypes, searchText, SORT_MAPPINGS[sortKey].orderBy, SORT_MAPPINGS[sortKey].order);
    }
    renderMediaList(disabled) {
        const { media, selectionType } = this.props;
        const isLoadingMedia = media.isLoading;
        const allItemsLoaded = media.allItemsLoaded();
        const mediaItems = media.getItems();
        const mediaItemRefs = media.references;
        return (<div className="media-list">
        <div className="list-header">
          <div className="sel-col"/>
          <div className="name-col">Name</div>
          <div className="refs-col">References</div>
          <div className="date-col">Date Modified</div>
          <div className="size-col">Size</div>
        </div>
        <div className="list-body" ref={(el) => this.setupScrollListener(el)}>
          <div ref={(el) => (this.scrollContent = el)}>
            {mediaItems.map((item) => (<div key={item.guid} className={`media-item ${this.isSelected(item.guid) ? 'selected' : ''} ` +
                    `${this.isItemSelectable(selectionType, item) && !disabled
                        ? 'selectable'
                        : 'not-selectable'}`} onClick={() => this.isItemSelectable(selectionType, item) && !disabled
                    ? this.onSelect(item.guid)
                    : null}>
                <div className="sel-col">
                  <input type="checkbox" readOnly className="selection-check" checked={this.isSelected(item.guid)} onClick={() => this.onSelect(item.guid)}/>
                </div>
                <div className="name-col">
                  <MediaIcon filename={item.fileName} mimeType={item.mimeType} url={item.url}/>
                  {` ${item.fileName}`}
                </div>
                <div className="refs-col">
                  {mediaItemRefs.get(item.guid) && mediaItemRefs.get(item.guid).size}
                </div>
                <div className="date-col">{item.dateUpdated}</div>
                <div className="size-col">{convert.toByteNotation(item.fileSize)}</div>
              </div>))}
            {isLoadingMedia && !allItemsLoaded ? (<LoadingSpinner key="loading" size={LoadingSpinnerSize.Small} message={PAGE_LOADING_MESSAGE}/>) : null}
          </div>
        </div>
      </div>);
    }
    renderMediaGrid(disabled) {
        const { media, selectionType } = this.props;
        const isLoadingMedia = media.isLoading;
        const allItemsLoaded = media.allItemsLoaded();
        const mediaItems = media.getItems();
        return (<div className="media-grid" ref={(el) => this.setupScrollListener(el)}>
        <div className="scroll-content" ref={(el) => (this.scrollContent = el)}>
          {mediaItems.map((item) => (<div key={item.guid} className={`media-item ${this.isSelected(item.guid) ? 'selected' : ''} ` +
                    `${this.isItemSelectable(selectionType, item) && !disabled
                        ? 'selectable'
                        : 'not-selectable'}`} onClick={() => this.isItemSelectable(selectionType, item) && !disabled
                    ? this.onSelect(item.guid)
                    : null}>
              <input type="checkbox" readOnly className="selection-check" checked={this.isSelected(item.guid)} onClick={() => this.onSelect(item.guid)}/>
              <MediaIcon filename={item.fileName} mimeType={item.mimeType} url={item.url}/>
              <div className="name">
                {stringFormat.ellipsize(item.fileName, MAX_NAME_LENGTH, 5)}
              </div>
            </div>))}
        </div>
        {isLoadingMedia && !allItemsLoaded ? (<div className="loading">
            <i className="fas fa-circle-notch fa-spin fa-1x fa-fw"/>
            {PAGE_LOADING_MESSAGE}
          </div>) : null}
      </div>);
    }
    renderMediaSelectionDetails(disabled) {
        const { media } = this.props;
        const { selection, showDetails } = this.state;
        const selectedMediaItems = selection.map((guid) => media.data.get(guid));
        if (selectedMediaItems.size > 1) {
            return (<div className="media-selection-details">
          <div className="details-title">Multiple Items Selected</div>
        </div>);
        }
        const detailsOnClick = () => this.setState({ showDetails: !showDetails });
        if (selectedMediaItems.size > 0) {
            const selectedItem = selectedMediaItems.first();
            return (<div className="media-selection-details">
          <div className="details-title">
            <span>
              Selected:{' '}
              <a href={selectedItem.url} rel="noreferrer" target="_blank" onClick={(e) => {
                    if (!disabled) {
                        popOpenImage(e);
                    }
                }}>
                {stringFormat.ellipsize(selectedItem.fileName, 65, 5)}
              </a>
            </span>
            {showDetails ? (<span role="button" onClick={detailsOnClick} className="material-icons">
                keyboard_arrow_down
              </span>) : (<span role="button" onClick={detailsOnClick} className="material-icons">
                keyboard_arrow_up
              </span>)}
          </div>
          {showDetails && (<div className="details-content">
              <MediaIcon filename={selectedItem.fileName} mimeType={selectedItem.mimeType} url={selectedItem.url}/>
              <div className="details-info">
                <div className="detail-row date-created">
                  <b>Uploaded:</b> {relativeToNow(new Date(selectedItem.dateCreated))}
                </div>
                <div className="detail-row file-size">
                  <b>Size:</b> {convert.toByteNotation(selectedItem.fileSize)}
                </div>
              </div>
            </div>)}
        </div>);
        }
    }
    renderError() {
        const { error } = this.state;
        return error.caseOf({
            just: (error) => (<div className="alert alert-danger fade show" role="alert">
          {error}
        </div>),
            nothing: () => null,
        });
    }
    render() {
        const { className, mimeFilter, media } = this.props;
        const { searchText, layout, orderBy, order } = this.state;
        const disabled = this.props.disabled === undefined ? false : this.props.disabled;
        const id = guid();
        const mediaCount = { numResults: media.totalItemsLoaded, totalResults: media.totalItems };
        return (<div className={`media-manager ${className || ''}`}>
        {this.renderError()}
        <div className="media-toolbar">
          <input id={id} style={{ display: 'none' }} disabled={disabled} accept={mimeFilter && `${mimeFilter}`} multiple onChange={({ target: { files } }) => this.onFileUpload(files)} type="file"/>
          <button disabled={disabled} className="btn btn-primary media-toolbar-item upload" onClick={() => this.onUploadClick(id)}>
            <i className="fa fa-upload"/> Upload
          </button>
          <div className="media-toolbar-item btn-group layout-control">
            <button disabled={disabled} className={`btn btn-outline-primary ${layout === LAYOUTS.GRID ? 'selected' : ''}`} onClick={() => this.onChangeLayout(LAYOUTS.GRID)}>
              <i className="fa fa-th"/> Grid
            </button>
            <button disabled={disabled} className={`btn btn-outline-primary ${layout === LAYOUTS.LIST ? 'selected' : ''}`} onClick={() => this.onChangeLayout(LAYOUTS.LIST)}>
              <i className="fa fa-th-list"/> List
            </button>
          </div>

          <div className="flex-grow-1"></div>

          <div className="media-toolbar-item sort-control dropdown">
            Sort by:&nbsp;
            <span className="dropdown-toggle sort-btn" id="dropdownMenu2" data-toggle="dropdown">
              <i className={SORT_MAPPINGS[getSortMappingKey(orderBy, order)].icon}/>
              {` ${getSortMappingKey(orderBy, order)}`}
            </span>
            <div className="dropdown-menu">
              {Object.keys(SORT_MAPPINGS).map((sortKey) => (<button disabled={disabled} key={sortKey} type="button" className="dropdown-item" onClick={() => this.onSortChange(sortKey)}>
                  {sortKey}
                </button>))}
            </div>
          </div>
          <div className="media-toolbar-item search">
            <div className="input-group">
              <input disabled={disabled} type="text" className="form-control" placeholder="Search" value={searchText} onChange={({ target: { value } }) => this.onSearch(value)}/>
            </div>
          </div>
        </div>
        <div className="media-library">
          <ol className="media-sidebar text-center">
            <li className={this.mimeTypeFilter(MIMETYPE_FILTERS.ALL)} onClick={() => this.displayMediaOfType(MIMETYPE_FILTERS.ALL)}>
              All Media
            </li>
            <li className={this.mimeTypeFilter(MIMETYPE_FILTERS.IMAGE)} onClick={() => this.displayMediaOfType(MIMETYPE_FILTERS.IMAGE)}>
              Images
            </li>
            <li className={this.mimeTypeFilter(MIMETYPE_FILTERS.AUDIO)} onClick={() => this.displayMediaOfType(MIMETYPE_FILTERS.AUDIO)}>
              Audio
            </li>
            <li className="video d-flex flex-column">
              <span>Video</span>
              <small>Managed by YouTube</small>
            </li>
          </ol>
          <div className="media-content">
            {layout === LAYOUTS.GRID
                ? this.renderMediaGrid(disabled)
                : this.renderMediaList(disabled)}
            {this.renderMediaSelectionDetails(disabled)}
          </div>
        </div>
        <div className="media-infobar">
          <div className="flex-spacer"/>
          {mediaCount && mediaCount.totalResults > -Infinity && (<div>
              Showing {mediaCount.numResults} of {mediaCount.totalResults}
            </div>)}
        </div>
      </div>);
    }
}
//# sourceMappingURL=MediaManager.jsx.map