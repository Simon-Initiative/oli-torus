import * as Immutable from 'immutable';
import { MediaItem, MediaRef } from 'types/media';

type OrderedMediaLibraryParams = {
  data?: Immutable.Map<string, MediaItem>;
  items?: Immutable.List<string>;
  references?: Immutable.Map<string, Immutable.List<MediaRef>>;
  totalItems?: number;
  totalItemsLoaded?: number;
  isLoading?: boolean;
  lastReqId?: string;
};

const defaultContent = {
  data: Immutable.Map<string, MediaItem>(),
  items: Immutable.List<string>(),
  references: Immutable.Map<string, Immutable.List<MediaRef>>(),
  totalItems: -Infinity,
  totalItemsLoaded: 0,
  isLoading: false,
  lastReqId: '',
};

export class OrderedMediaLibrary extends Immutable.Record(defaultContent) {
  data: Immutable.Map<string, MediaItem>;
  items: Immutable.List<string>;
  references: Immutable.Map<string, Immutable.List<MediaRef>>;
  totalItems: number;
  totalItemsLoaded: number;
  isLoading: boolean;
  lastReqId: string;

  constructor(params?: OrderedMediaLibraryParams) {
    super(params);
  }

  with(values: OrderedMediaLibraryParams) {
    return this.merge(values) as this;
  }

  getItem(guid: string) {
    return this.data.get(guid);
  }

  getItems(offset: number = 0, count: number = this.items.size) {
    return this.items.slice(offset, count).map(guid => this.data.get(guid)).toArray();
  }

  allItemsLoaded() {
    return this.totalItems > -Infinity && this.totalItemsLoaded >= this.totalItems;
  }

  load(items: Immutable.List<MediaItem>, totalItems: number) {
    return this.with({
      data: this.data.merge(items.reduce(
        (acc, i) => acc.set(i.guid, i), Immutable.Map<string, MediaItem>())),
      items: this.items.concat(items.map(i => i.guid)) as Immutable.List<string>,
      totalItems,
      totalItemsLoaded: this.totalItemsLoaded + items.size,
    });
  }

  sideloadData(data: Immutable.Map<string, MediaItem>) {
    return this.with({ data: this.data.merge(data) });
  }

  getReferences(guid: string) {
    return this.references.get(guid);
  }

  loadReferences(references: Immutable.Map<string, Immutable.List<MediaRef>>) {
    return this.with({ references: this.references.merge(references) });
  }

  clearItems() {
    // reset media library but keep data and reference cache
    return this.with({
      data: this.data,
      items: Immutable.List<string>(),
      references: this.references,
      totalItems: -Infinity,
      totalItemsLoaded: 0,
      isLoading: false,
    });
  }
}
