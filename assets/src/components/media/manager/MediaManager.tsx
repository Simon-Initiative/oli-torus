import * as React from 'react';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { MediaIcon } from './MediaIcon';
import { Media, MediaItem, MediaRef } from 'types/media';
import guid from 'utils/guid';
import { convert, stringFormat } from 'utils/format';
import * as persistence from 'data/persistence/media';
import { OrderedMediaLibrary } from '../OrderedMediaLibrary';
import './MediaManager.scss';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';

const PAGELOAD_TRIGGER_MARGIN_PX = 100;
const MAX_NAME_LENGTH = 26;
const PAGE_LOADING_MESSAGE = 'Hang on while more items are loaded...';

export const MIMETYPE_FILTERS = {
  IMAGE: ['image/jpeg', 'image/png', 'image/jpeg', 'image/gif'],
  AUDIO: ['audio/mpeg'],
  VIDEO:  ['video/mp4'],
  HTML: ['text/html'],
  ALL: [''],
};

export enum SELECTION_TYPES {
  MULTI,
  SINGLE,
  NONE,
}

export enum LAYOUTS {
  GRID,
  LIST,
}

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
} as any;

const getSortMappingKey = (orderBy: string, order?: string) => {
  return Object.keys(SORT_MAPPINGS).find(key =>
    orderBy === SORT_MAPPINGS[key].orderBy
    && (order === undefined || order === SORT_MAPPINGS[key].order));
};

const popOpenImage = (e : any) => {
  const link = e.target;
  const w = window.open(
    link.href,
    link.target || '_blank',
    'menubar=no,toolbar=no,location=no,directories=no,status=no,scrollbars=no,'
    + 'resizable=no,dependent,width=800,height=620',
  );

  // allow the link to work if popup is blocked
  return w ? false : true;
};

export interface MediaManagerProps {
  className?: string;
  projectSlug: string;
  model: Media;
  media: OrderedMediaLibrary;
  mimeFilter?: string[];
  selectionType: SELECTION_TYPES;
  initialSelectionPaths: string[];
  onEdit: (updated: Media) => void;
  onLoadCourseMediaNextPage: (projectSlug: string,
    mimeFilter: string[], searchText: string,
    orderBy: string, order: string) => Promise<Maybe<Immutable.List<MediaItem>>>;
  onResetMedia: () => void;
  onSelectionChange: (selection: MediaItem[]) => void;
  onLoadMediaItemByPath: (projectSlug: string, path: string) => Promise<Maybe<MediaItem>>;
}

export interface MediaManagerState {
  selection: Immutable.List<string>;
  searchText: string | undefined;
  orderBy: string;
  order: string;
  layout: LAYOUTS;
  showDetails: boolean;
}

/**
 * MediaManager React Component
 */
export class MediaManager extends React.PureComponent<MediaManagerProps, MediaManagerState> {
  scrollView: HTMLElement;
  scrollContent: HTMLElement;

  constructor(props: MediaManagerProps) {
    super(props);

    this.state = {
      selection: Immutable.List<string>(),
      searchText: undefined,
      orderBy: SORT_MAPPINGS.Newest.orderBy,
      order: SORT_MAPPINGS.Newest.order,
      layout: LAYOUTS.GRID,
      showDetails: true,
    };

    this.onScroll = this.onScroll.bind(this);
    this.isSelected = this.isSelected.bind(this);
    this.onSelect = this.onSelect.bind(this);
    this.onSearch = this.onSearch.bind(this);
    this.onChangeLayout = this.onChangeLayout.bind(this);
  }

  componentDidMount() {
    const { mimeFilter, initialSelectionPaths,
      onLoadCourseMediaNextPage, onLoadMediaItemByPath } = this.props;
    const { searchText, orderBy, order } = this.state;

    onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter as string[],
      searchText as string, orderBy, order);

    // load initial selection data
    if (initialSelectionPaths) {
      Promise.all(initialSelectionPaths.filter(path => path).map(path =>
        onLoadMediaItemByPath(this.props.projectSlug, path.replace(/^[./]+/, ''))),
      ).then((mediaItems) => {
        this.setState({
          selection: Immutable.List(
            mediaItems.map(mi =>
              mi.caseOf({
                just: item => item.guid,
                nothing: () => undefined,
              }) as string,
            ).filter(i => i),
          ),
        });
      });
    }
  }

  componentWillUnmount() {
    const { onResetMedia } = this.props;

    this.scrollView.removeEventListener('scroll', this.onScroll);
    onResetMedia();
  }

  onUploadClick(id: string) {
    (window as any).$('#' + id).trigger('click');
  }

  setupScrollListener(scrollView: HTMLElement) {
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
    const { media, mimeFilter, onLoadCourseMediaNextPage } = this.props;
    const { searchText, orderBy, order } = this.state;

    const isLoadingMedia = media.isLoading;

    const allItemsLoaded = media.items.size >= media.totalItems;

    if (allItemsLoaded) {
      this.scrollView.removeEventListener('scroll', this.onScroll);
      return;
    }

    if (!isLoadingMedia && this.scrollView.scrollTop + PAGELOAD_TRIGGER_MARGIN_PX
      > (this.scrollContent.offsetHeight - this.scrollView.offsetHeight)) {
      onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter as string[],
        searchText as string, orderBy, order);
    }
  }

  onFileUpload(files: FileList) {
    const { mimeFilter, onLoadCourseMediaNextPage,
      onResetMedia } = this.props;
    const { searchText, orderBy, order } = this.state;

    // get a list of the files to upload
    const fileList : File[] = [];
    for (let i = 0; i < files.length; i = i + 1) {
      fileList.push(files[i]);
    }

    // the server creates a lock on upload, so we must upload files one at a
    // time. This factory function returns a new promise to upload a file
    // recursively until fileList is empty
    const results : any = [];
    const createWebContentPromiseFactory = (courseId : string, file: File) : any =>
      persistence.createMedia(courseId, file)
        .then((result) => {
          results.push(result);

          if (fileList.length > 0) {
            const top = (fileList.pop() as any) as File;
            return createWebContentPromiseFactory(courseId, top);
          }

          return results;
        });

    // sequentially upload files one at a time, then reload the media page
    createWebContentPromiseFactory(this.props.projectSlug, fileList.pop() as any)
      .then((result: any) => {
        onResetMedia();
        onLoadCourseMediaNextPage(this.props.projectSlug,
          mimeFilter as string[], searchText as string, orderBy, order)
          // select the most recently uploaded item
          .then((mediaItems) => {
            mediaItems.lift((files) => {
              if (files.size > 0) {
                Maybe.maybe(files.find(f => f.url === result[0])).lift(file =>
                  this.onSelect(file.guid));
              }
            });
          });
      });
  }

  onChangeLayout(newLayout: LAYOUTS) {
    this.setState({
      layout: newLayout,
    });
  }

  isSelected(guid: string) {
    const { selection } = this.state;

    return selection.includes(guid);
  }

  onSelect(guid: string) {
    const { media, selectionType, onSelectionChange } = this.props;
    const { selection } = this.state;

    let updatedSelection = selection;

    if (selectionType === SELECTION_TYPES.SINGLE) {
      // clear the current selection
      updatedSelection = Immutable.List([guid]);
    } else if (selectionType === SELECTION_TYPES.MULTI) {
      if (this.isSelected(guid)) {
        // unselect item
        updatedSelection = updatedSelection.remove(updatedSelection.findIndex(s => s === guid));
      } else {
        // select item
        updatedSelection = updatedSelection.push(guid);
      }
    } else {
      return;
    }

    this.setState({
      selection: updatedSelection,
    });

    const mediaLibrary = media;
    if (mediaLibrary) {
      onSelectionChange(
        updatedSelection.map(s => mediaLibrary.getItem(s)).toArray() as MediaItem[]);
    }
  }

  onSearch(searchText: string) {
    const { mimeFilter, onLoadCourseMediaNextPage, onResetMedia } = this.props;
    const { orderBy, order } = this.state;

    onResetMedia();
    onLoadCourseMediaNextPage(this.props.projectSlug, mimeFilter as string[],
      searchText, orderBy, order);
  }

  onSortChange(sortKey: string) {
    const { mimeFilter, onLoadCourseMediaNextPage, onResetMedia } = this.props;
    const { searchText } = this.state;

    this.setState({
      orderBy: SORT_MAPPINGS[sortKey].orderBy,
      order: SORT_MAPPINGS[sortKey].order,
    });

    onResetMedia();
    onLoadCourseMediaNextPage(this.props.projectSlug,
      mimeFilter as string[], searchText as string,
      SORT_MAPPINGS[sortKey].orderBy, SORT_MAPPINGS[sortKey].order);
  }

  renderMediaList() {
    const { media, selectionType } = this.props;

    const isLoadingMedia = media.isLoading;

    const allItemsLoaded = media.allItemsLoaded();

    const mediaItems: MediaItem[] = media.getItems() as MediaItem[];

    const mediaItemRefs = media.references;

    return (
      <div className="media-list">
        <div className="list-header">
          <div className="sel-col" />
          <div className="name-col">Name</div>
          <div className="refs-col">References</div>
          <div className="date-col">Date Modified</div>
          <div className="size-col">Size</div>
        </div>
        <div className="list-body" ref={el => this.setupScrollListener(el as HTMLElement)}>
          <div ref={el => this.scrollContent = el as HTMLElement}>
            {mediaItems.map(item => (
              <div key={item.guid}
                className={
                  `media-item ${this.isSelected(item.guid) ? 'selected' : ''} `
                  + `${selectionType !== SELECTION_TYPES.NONE ? 'selectable' : ''}`}
                onClick={() => this.onSelect(item.guid)}>
                <div className="sel-col">
                  <input
                    type="checkbox"
                    readOnly
                    className="selection-check"
                    checked={this.isSelected(item.guid)}
                    onClick={() => this.onSelect(item.guid)} />
                </div>
                <div className="name-col">
                  <MediaIcon
                    filename={item.fileName}
                    mimeType={item.mimeType}
                    url={item.url} />
                  {` ${item.fileName}`}
                </div>
                <div className="refs-col">
                  {mediaItemRefs.get(item.guid) && (mediaItemRefs.get(item.guid) as any).size}
                </div>
                <div className="date-col">{item.dateUpdated}</div>
                <div className="size-col">{convert.toByteNotation(item.fileSize)}</div>
              </div>
            ))}
            {isLoadingMedia && !allItemsLoaded
              ? <LoadingSpinner key="loading"
                size={LoadingSpinnerSize.Small} message={PAGE_LOADING_MESSAGE} />
              : null
            }
          </div>
        </div>
      </div>
    );
  }

  renderMediaGrid() {
    const { media, selectionType } = this.props;

    const isLoadingMedia = media.isLoading;

    const allItemsLoaded = media.allItemsLoaded();

    const mediaItems: MediaItem[] = media.getItems() as MediaItem[];

    return (
      <div className="media-grid" ref={el => this.setupScrollListener(el as HTMLElement)}>
        <div className="scroll-content" ref={el => this.scrollContent = el as HTMLElement}>
          {mediaItems.map(item => (
            <div key={item.guid}
              className={`media-item ${this.isSelected(item.guid) ? 'selected' : ''} `
                + `${selectionType !== SELECTION_TYPES.NONE ? 'selectable' : ''}`}
              onClick={() => this.onSelect(item.guid)}>
              <input
                type="checkbox"
                readOnly
                className="selection-check"
                checked={this.isSelected(item.guid)}
                onClick={() => this.onSelect(item.guid)} />
              <MediaIcon
                filename={item.fileName}
                mimeType={item.mimeType}
                url={item.url} />
              <div className="name">
                {stringFormat.ellipsize(item.fileName, MAX_NAME_LENGTH, 5)}
              </div>
            </div>
          ))}
        </div>
        {isLoadingMedia && !allItemsLoaded
          ? (
            <div className="loading">
              <i className="fas fa-circle-notch fa-spin fa-1x fa-fw" />
              {PAGE_LOADING_MESSAGE}
            </div>
          )
          : null
        }
      </div>
    );
  }

  renderMediaSelectionDetails() {
    const { media } = this.props;
    const { selection, showDetails } = this.state;

    const selectedMediaItems = selection
      .map(guid => media.data.get(guid)) as Immutable.List<MediaItem>;

    const mediaItemRefs = media.references;

    if (selectedMediaItems.size > 1) {
      return (
        <div className="media-selection-details">
          <div className="details-title">
            Multiple Items Selected
          </div>
        </div>
      );
    }

    if (selectedMediaItems.size > 0) {
      const selectedItem = selectedMediaItems.first() as MediaItem;

      return (
        <div className="media-selection-details">
          <div className="details-title">
            <a
              href={selectedItem.url}
              target="_blank"
              onClick={popOpenImage} >
              {stringFormat.ellipsize(selectedItem.fileName, 65, 5)}</a>
            <div className="flex-spacer" />
            <button className="btn btn-link" onClick={() =>
              this.setState({ showDetails: !showDetails })}>
              {showDetails ? 'Hide' : 'Details'}
            </button>
          </div>
          {showDetails &&
            <div className="details-content">
              <MediaIcon
                filename={selectedItem.fileName}
                mimeType={selectedItem.mimeType}
                url={selectedItem.url} />
              <div className="details-info">
                <div className="detail-row date-created">
                  <b>Created:</b> {selectedItem.dateCreated}
                </div>
                <div className="detail-row date-updated">
                  <b>Updated:</b> {selectedItem.dateUpdated}
                </div>
                <div className="detail-row file-size">
                  <b>Size:</b> {convert.toByteNotation(selectedItem.fileSize)}
                </div>
              </div>
              <div className="details-page-refs">
                <div>
                  <b>References:</b> {
                    mediaItemRefs.get(selectedItem.guid)
                      ? (
                        (mediaItemRefs.get(selectedItem.guid) as any).size
                      )
                      : (
                        <i className="fas fa-circle-notch fa-spin fa-1x fa-fw" />
                      )
                  }
                </div>
                <div>
                  {mediaItemRefs.get(selectedItem.guid)
                    && (mediaItemRefs.get(selectedItem.guid) as any).map((ref : any, i : any) => (
                      <span key={ref.guid}>
                        <a href="#"
                          onClick={(e) => {
                            e.preventDefault();
                            // viewActions.viewDocument(
                            //  ref.resourceId, courseModel.idvers, Maybe.nothing());
                          }}
                          target="_blank">
                          None
                        </a>
                        {i < (mediaItemRefs.get(selectedItem.guid) as any).size - 1 ? ', ' : ''}
                      </span>
                    ))
                  }
                </div>
              </div>
            </div>
          }
        </div>
      );
    }
  }

  render() {
    const { className, mimeFilter, media } = this.props;
    const { searchText, layout, orderBy, order } = this.state;

    const id = guid();

    const mediaCount = ({ numResults: media.totalItemsLoaded, totalResults: media.totalItems });

    return (
      <div className={`media-manager ${className || ''}`}>
        <div className="media-toolbar">
          <input
            id={id}
            style={{ display: 'none' }}
            accept={mimeFilter && `${mimeFilter}/*`}
            multiple={true}
            onChange={({ target: { files } }) => this.onFileUpload(files as FileList)}
            type="file" />
          <button
            className="btn btn-primary media-toolbar-item upload"
            onClick={() => this.onUploadClick(id)}>
            <i className="fa fa-upload" /> Upload
          </button>
          <div className="media-toolbar-item layout-control">
            <button
              className={`btn btn-outline-primary ${layout === LAYOUTS.GRID ? 'selected' : ''}`}
              onClick={() => this.onChangeLayout(LAYOUTS.GRID)}>
              <i className="fa fa-th" />
            </button>
            <button
              className={`btn btn-outline-primary ${layout === LAYOUTS.LIST ? 'selected' : ''}`}
              onClick={() => this.onChangeLayout(LAYOUTS.LIST)}>
              <i className="fa fa-th-list" />
            </button>
          </div>
          <div className="media-toolbar-item flex-spacer" />
          <div className="media-toolbar-item sort-control dropdown">
            Sort By:
            <button
              className="btn btn-secondary dropdown-toggle sort-btn"
              type="button" id="dropdownMenu2"
              data-toggle="dropdown">
              <i className={SORT_MAPPINGS[getSortMappingKey(orderBy, order) as any].icon} />
              {` ${getSortMappingKey(orderBy, order)}`}
            </button>
            <div className="dropdown-menu">
              {Object.keys(SORT_MAPPINGS).map(sortKey =>
                <button
                  key={sortKey}
                  type="button"
                  className="dropdown-item"
                  onClick={() => this.onSortChange(sortKey)}>
                  {sortKey}
                </button>,
              )}
            </div>
          </div>
          <div className="media-toolbar-item search">
            <div className="input-group">
              <input
                type="text"
                className="form-control"
                placeholder="Search"
                value={searchText}
                onChange={({ target: { value } }) => this.onSearch(value)} />
            </div>
          </div>
        </div>
        <div className="media-library">
          <ol className="media-sidebar">
            <li className="active">All Media</li>
            {/* <li className="">Unit 1</li>
            <li className="">Unit 2</li> */}
          </ol>
          <div className="media-content">
            {layout === LAYOUTS.GRID
              ? (this.renderMediaGrid())
              : (this.renderMediaList())
            }
            {this.renderMediaSelectionDetails()}
          </div>
        </div>
        <div className="media-infobar">
          <div className="flex-spacer" />
          {mediaCount && mediaCount.totalResults > -Infinity &&
            <div>Showing {mediaCount.numResults} of {mediaCount.totalResults}</div>
          }
        </div>
      </div>
    );
  }
}
