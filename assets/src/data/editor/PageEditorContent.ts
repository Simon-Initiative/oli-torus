import * as Immutable from 'immutable';
import {
  createDefaultStructuredContent,
  createGroup,
  GroupContent,
  ResourceContent,
} from 'data/content/resource';
import guid from 'utils/guid';

type PageEditorContentParams = {
  version: string;
  model: Immutable.List<ResourceContent>;
};

const defaultParams = (params: Partial<PageEditorContentParams> = {}): PageEditorContentParams => ({
  version: params.version as string,
  model: params.model ?? Immutable.List<ResourceContent>(),
});

export class PageEditorContent extends Immutable.Record(defaultParams()) {
  version: string;
  model: Immutable.List<ResourceContent>;

  constructor(params?: PageEditorContentParams) {
    params ? super(params) : super();
  }

  with(values: Partial<PageEditorContentParams>) {
    return this.merge(values) as this;
  }

  /**
   * Finds a content item
   * @param key id of the item to find
   * @returns found content item
   */
  find(key: string) {
    return findContentItem(this.model, key);
  }

  /**
   * Finds the index of a content item using a given function
   * @param fn fn that runs on every element and returns true for the element being searched for
   * @returns index array of the found content element where each index in the array corresponds
   *          to a level in the hierarchy
   */
  findIndex(fn: (c: ResourceContent) => boolean) {
    return findIndex(this.model, fn);
  }

  /**
   * Returns a new instance of this Record type with the value for the specific key removed.
   * @param key key of the item to remove
   * @returns page editor content without the deleted item
   */
  delete(key: string) {
    return this.with({ model: filterContentItem(this.model, key) });
  }

  /**
   * Inserts the resource content item at the specified index, where index is an array
   * of indices for each level in the hierarchy.
   *
   * This function does its best to succeed when given invalid indices. If a group item
   * does not exist at a particular index for a given level, the item will be inserted at
   * that position. If an index is out of bounds, it will be placed in the last valid position.
   * @param index
   * @param toInsert
   * @return page editor content with the inserted item
   */
  insertAt(index: number[], toInsert: ResourceContent) {
    return this.with({ model: insertAt(this.model, index, toInsert) });
  }

  /**
   *
   * @param key Updates the content item with the given key
   * @param key Key of the item to update
   * @param updated Updated content item
   * @returns updated page editor content
   */
  updateContentItem(key: string, updated: ResourceContent) {
    return this.with({ model: updateContentItem(this.model, key, updated) });
  }

  /**
   * Updates all content items with the given function
   * @param fn update function
   * @returns updated page editor content
   */
  updateAll(fn: (item: ResourceContent) => ResourceContent) {
    return this.with({ model: updateAll(this.model, fn) });
  }

  /**
   * @returns a flattened list of all content elements where groups are inserted before
   * their children (pre-order traversal)
   */
  flatten(): Immutable.List<ResourceContent> {
    return flatten(this.model);
  }

  /**
   * @param key
   * @returns the index of the item from the flattened list of items
   */
  flattenedIndex(key: string) {
    return flatten(this.model).findIndex((c) => c.id === key);
  }

  /**
   * @returns the count of all resource content items
   */
  count() {
    return this.flatten().size;
  }

  /**
   * @returns true if an item can be deleted from the model
   */
  canDelete() {
    return this.model.size > 1;
  }

  /**
   * @returns the first resource content item
   */
  first() {
    return this.model.first<ResourceContent>();
  }

  /**
   * @returns the last resource content item
   */
  last() {
    return this.flatten().last<ResourceContent>();
  }

  /**
   * Converts the page editor content to a plain-old js object
   * @returns persistence compatible js object
   */
  toPersistence(): { version: string; model: ResourceContent[] } {
    return { version: this.version, model: toPersistence(this.model) };
  }

  /**
   * Converts the plain-old js object to a page editor content representation
   * @returns page editor content representation
   */
  static fromPersistence(content: any) {
    return new PageEditorContent({
      version: content.version,
      model: withDefaultContent(fromPersistence(content.model)),
    });
  }
}

/**
 * Ensures that there is some default content if the initial content of this resource is empty
 * @param content
 * @returns
 */
function withDefaultContent(
  content: Immutable.List<ResourceContent>,
): Immutable.List<ResourceContent> {
  if (content.size > 0) {
    return content.map((contentItem) => {
      // There is the possibility that ingested course material did not specify the
      // id attribute. If so, we will assign one here that will get persisted once the user
      // edits the page.
      contentItem =
        contentItem.id === undefined ? Object.assign({}, contentItem, { id: guid() }) : contentItem;
      return contentItem;
    });
  }

  return Immutable.List<ResourceContent>([createDefaultStructuredContent()]);
}

function findContentItem(
  items: Immutable.List<ResourceContent>,
  key: string,
  acc: ResourceContent | undefined = undefined,
): ResourceContent | undefined {
  return items.reduce((acc, c) => {
    if (c.id === key) return c;

    return c.type === 'group' ? findContentItem(c.children, key, acc) : acc;
  }, acc);
}

function findIndex(
  items: Immutable.List<ResourceContent>,
  fn: (c: ResourceContent) => boolean,
  parentIndices: number[] = [],
  acc: number[] = [],
): number[] {
  return items.reduce((acc, c, index) => {
    if (fn(c)) return [...parentIndices, index];

    return c.type === 'group' ? findIndex(c.children, fn, [...parentIndices, index], acc) : acc;
  }, acc);
}

function filterContentItem(
  items: Immutable.List<ResourceContent>,
  key: string,
): Immutable.List<ResourceContent> {
  return items.reduce((acc, c) => {
    if (c.id === key) return acc;

    if (c.type === 'group') {
      c.children = filterContentItem(c.children, key);
    }
    return acc.push(c);
  }, Immutable.List<ResourceContent>());
}

function insertAt(
  items: Immutable.List<ResourceContent>,
  index: number[],
  toInsert: ResourceContent,
): Immutable.List<ResourceContent> {
  const currentIndex = index[0];
  if (index.length > 1 && items.get(currentIndex)?.type === 'group') {
    return items.update(currentIndex, createGroup(), (item) => {
      (item as GroupContent).children = insertAt(
        (item as GroupContent).children,
        index.slice(1),
        toInsert,
      );
      return item;
    });
  }

  return items.insert(currentIndex, toInsert);
}

function updateContentItem(
  items: Immutable.List<ResourceContent>,
  key: string,
  updated: ResourceContent,
): Immutable.List<ResourceContent> {
  return items.map((c) => {
    if (c.id === key) {
      return updated;
    }

    if (c.type === 'group') {
      c.children = updateContentItem(c.children, key, updated);
    }

    return c;
  });
}

function updateAll(
  items: Immutable.List<ResourceContent>,
  fn: (item: ResourceContent) => ResourceContent,
): Immutable.List<ResourceContent> {
  return items.map((i) => {
    if (i.type === 'group') {
      i.children = updateAll(i.children, fn);
    }

    return fn(i);
  });
}

function flatten(items: Immutable.List<ResourceContent>) {
  return items.reduce((acc, item) => {
    acc = acc.push(item);

    if (item.type === 'group') {
      acc = acc.concat(flatten(item.children));
    }

    return acc;
  }, Immutable.List<ResourceContent>());
}

function toPersistence(items: Immutable.List<ResourceContent>): any[] {
  return items.reduce((acc, val) => {
    const children =
      val.type === 'group'
        ? toPersistence(val.children)
        : val.type === 'page-break'
        ? undefined
        : val.children;

    return [...acc, { ...val, children }];
  }, []);
}

function fromPersistence(items: any[]): Immutable.List<ResourceContent> {
  return items.reduce((acc, val) => {
    const children = val.type === 'group' ? fromPersistence(val.children) : val.children;

    return acc.push({ ...val, children });
  }, Immutable.List<ResourceContent>());
}
