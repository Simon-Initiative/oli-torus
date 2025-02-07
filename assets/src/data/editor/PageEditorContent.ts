import * as Immutable from 'immutable';
import {
  ResourceContent,
  ResourceGroup,
  createDefaultStructuredContent,
  createGroup,
  isResourceGroup,
} from 'data/content/resource';
import guid from 'utils/guid';
import { PageTrigger } from 'data/triggers';

type PageEditorContentParams = {
  version: string;
  model: Immutable.List<ResourceContent>;
  trigger: PageTrigger | undefined;
};

const defaultParams = (params: Partial<PageEditorContentParams> = {}): PageEditorContentParams => ({
  version: params.version as string,
  model: params.model ?? Immutable.List<ResourceContent>(),
  trigger: undefined
});

export class PageEditorContent extends Immutable.Record(defaultParams()) {
  version: string;
  model: Immutable.List<ResourceContent>;
  trigger: PageTrigger;

  constructor(params?: PageEditorContentParams) {
    params ? super(params) : super();
  }

  with(values: Partial<PageEditorContentParams>) {
    return this.merge(values) as this;
  }

  /**
   * Finds a content item
   * @param id id of the item to find
   * @returns found content item
   */
  find(id: string) {
    return findContentItem(this.model, id);
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
   * Returns a new instance of this Record type with the value for the specific id removed.
   * @param id id of the item to remove
   * @returns page editor content without the deleted item
   */
  delete(id: string) {
    return this.with({ model: filterContentItem(this.model, id) });
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
   * Replaces the resource content item at the specified index, where index is an array
   * of indices for each level in the hierarchy.
   *
   * If an item does not exist at a given index then the operation is a no-op.
   * @param index
   * @param toInsert
   * @return page editor content with the inserted item
   */
  replaceAt(index: number[], toReplace: ResourceContent) {
    return this.with({ model: replaceAt(this.model, index, toReplace) });
  }

  /**
   *
   * Updates the content item with the given id
   * @param id Identifier of the item to update
   * @param updated Updated content item
   * @returns updated page editor content
   */
  updateContentItem(id: string, updated: ResourceContent) {
    return this.with({ model: updateContentItem(this.model, id, updated) });
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
   * Find the index of an item from a flattened list of items
   * @param id
   * @returns the index of the item from the flattened list of items
   */
  flattenedIndex(id: string) {
    return flatten(this.model).findIndex((c) => c.id === id);
  }

  /**
   * @returns the count of all resource content items
   */
  count() {
    return this.flatten().size;
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
  toPersistence(): { version: string; model: ResourceContent[], trigger?: PageTrigger } {
    return { version: this.version, model: toPersistence(this.model), trigger: this.trigger };
  }

  /**
   * Converts the plain-old js object to a page editor content representation
   * @returns page editor content representation
   */
  static fromPersistence(content: any) {
    return new PageEditorContent({
      version: content.version,
      model: withDefaultContent(fromPersistence(content.model)),
      trigger: content.trigger,
    });
  }
}

/**
 * Ensures that there is some default content if the initial content of this resource is empty
 * @param content
 * @returns
 */
export function withDefaultContent(
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
  id: string,
  acc: ResourceContent | undefined = undefined,
): ResourceContent | undefined {
  return items.reduce((acc, c) => {
    if (c.id === id) return c;

    return isResourceGroup(c) ? findContentItem((c as ResourceGroup).children, id, acc) : acc;
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

    return isResourceGroup(c)
      ? findIndex((c as ResourceGroup).children, fn, [...parentIndices, index], acc)
      : acc;
  }, acc);
}

function filterContentItem(
  items: Immutable.List<ResourceContent>,
  id: string,
): Immutable.List<ResourceContent> {
  return items.reduce((acc, c) => {
    if (c.id === id) return acc;

    if (isResourceGroup(c)) {
      (c as ResourceGroup).children = filterContentItem((c as ResourceGroup).children, id);
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
  const currentItem = items.get(currentIndex);
  if (index.length > 1 && currentItem && isResourceGroup(currentItem)) {
    return items.update(currentIndex, createGroup(), (item) => {
      (item as ResourceGroup).children = insertAt(
        (item as ResourceGroup).children,
        index.slice(1),
        toInsert,
      );
      return item;
    });
  }

  return items.insert(currentIndex, toInsert);
}

function replaceAt(
  items: Immutable.List<ResourceContent>,
  index: number[],
  toReplace: ResourceContent,
): Immutable.List<ResourceContent> {
  const currentIndex = index[0];
  const currentItem = items.get(currentIndex);

  if (index.length > 1 && currentItem && isResourceGroup(currentItem)) {
    return items.update(currentIndex, createGroup(), (item) => {
      (item as ResourceGroup).children = replaceAt(
        (item as ResourceGroup).children,
        index.slice(1),
        toReplace,
      );

      return item;
    });
  }

  if (index.length === 1 && currentItem) {
    // this is the exact item at the index we are looking for so replace it
    return items.set(currentIndex, toReplace);
  }

  // an item could not be found at the specified index so nothing is changed
  return items;
}

function updateContentItem(
  items: Immutable.List<ResourceContent>,
  id: string,
  updated: ResourceContent,
): Immutable.List<ResourceContent> {
  return items.map((c) => {
    if (c.id === id) {
      return updated;
    }

    if (isResourceGroup(c)) {
      (c as ResourceGroup).children = updateContentItem((c as ResourceGroup).children, id, updated);
    }

    return c;
  });
}

function updateAll(
  items: Immutable.List<ResourceContent>,
  fn: (item: ResourceContent) => ResourceContent,
): Immutable.List<ResourceContent> {
  return items.map((i) => {
    if (isResourceGroup(i)) {
      const itemWithChildren = {
        ...i,
        children: updateAll((i as ResourceGroup).children, fn),
      } as ResourceGroup;
      return fn(itemWithChildren);
    }

    return fn(i);
  });
}

function flatten(items: Immutable.List<ResourceContent>) {
  return items.reduce((acc, item) => {
    acc = acc.push(item);

    if (isResourceGroup(item)) {
      acc = acc.concat(flatten((item as ResourceGroup).children));
    }

    return acc;
  }, Immutable.List<ResourceContent>());
}

function toPersistence(items: Immutable.List<ResourceContent>): any[] {
  return items.reduce((acc, val) => {
    const children = isResourceGroup(val)
      ? toPersistence((val as ResourceGroup).children)
      : val.type === 'break'
      ? undefined
      : val.children;

    return [...acc, { ...val, children }];
  }, []);
}

export function fromPersistence(items: any[]): Immutable.List<ResourceContent> {
  return items.reduce((acc, val) => {
    const children = isResourceGroup(val) ? fromPersistence(val.children) : val.children;

    return acc.push({ ...val, children });
  }, Immutable.List<ResourceContent>());
}
