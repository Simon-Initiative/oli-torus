import * as Immutable from 'immutable';
const defaultContent = {
    data: Immutable.Map(),
    items: Immutable.List(),
    references: Immutable.Map(),
    totalItems: -Infinity,
    totalItemsLoaded: 0,
    isLoading: false,
    lastReqId: '',
};
export class OrderedMediaLibrary extends Immutable.Record(defaultContent) {
    constructor(params) {
        super(params);
    }
    with(values) {
        return this.merge(values);
    }
    getItem(guid) {
        return this.data.get(guid);
    }
    getItems(offset = 0, count = this.items.size) {
        return this.items
            .slice(offset, count)
            .map((guid) => this.data.get(guid))
            .toArray();
    }
    allItemsLoaded() {
        return this.totalItems > -Infinity && this.totalItemsLoaded >= this.totalItems;
    }
    load(items, totalItems) {
        return this.with({
            data: this.data.merge(items.reduce((acc, i) => acc.set(i.guid, i), Immutable.Map())),
            items: this.items.concat(items.map((i) => i.guid)),
            totalItems,
            totalItemsLoaded: this.totalItemsLoaded + items.size,
        });
    }
    sideloadData(data) {
        return this.with({ data: this.data.merge(data) });
    }
    getReferences(guid) {
        return this.references.get(guid);
    }
    loadReferences(references) {
        return this.with({ references: this.references.merge(references) });
    }
    clearItems() {
        // reset media library but keep data and reference cache
        return this.with({
            data: this.data,
            items: Immutable.List(),
            references: this.references,
            totalItems: -Infinity,
            totalItemsLoaded: 0,
            isLoading: false,
        });
    }
}
//# sourceMappingURL=OrderedMediaLibrary.js.map