import jp from 'jsonpath';

export type PathOperation = FindOperation | InsertOperation | ReplaceOperation | FilterOperation;

// apply a series of transformations which may mutate the given json
export function applyAll(json: Record<string, any>, ops: PathOperation[]): void {
  ops.forEach((op) => op && apply(json, op));
}

// apply a single operation and return the possibly transformed value
export function apply(json: Record<string, any>, op: PathOperation): any[] {
  if (op.type === 'FindOperation') {
    // jsonpath returns a list of lists that match the path
    return jp.query(json, op.path).reduce((acc, result) => acc.concat(result), []);
  }

  return jp.apply(json, op.path, (result) => {
    if (op.type === 'InsertOperation') {
      // Impl of 'InsertOperation' is to insert at a specific index an item
      // into an array
      if (op.index === undefined || op.index === -1) {
        result.push(op.item);
      } else {
        result.splice(op.index, 0, op.item);
      }
      return result;
    }
    if (op.type === 'ReplaceOperation') {
      // Impl of 'ReplaceOperation' is simply returning the value of item
      // that will then replace the item matched via 'path'
      return op.item;
    }

    if (op.type === 'FilterOperation') {
      // This effectively replaces the results that match `op.path` with the results of `op.predicatePath`
      return jp.query(json, op.path + op.predicatePath);
    }
  });
}

// Find an element in a list
export type FindOperation = {
  type: 'FindOperation';
  path: string;
};

// Insert into a list
export type InsertOperation = {
  type: 'InsertOperation';
  path: string;
  index?: number;
  item: any;
};

// Replace the contents
export type ReplaceOperation = {
  type: 'ReplaceOperation';
  path: string;
  item: any;
};

// Filter the list at `path` using `predicatePath`
export type FilterOperation = {
  type: 'FilterOperation';
  path: string;
  predicatePath: string;
};

export const find = (path: string): FindOperation => ({
  type: 'FindOperation',
  path,
});

export const insert = (path: string, item: any, index?: number): InsertOperation => ({
  type: 'InsertOperation',
  path,
  item,
  index,
});

export const replace = (path: string, item: any): ReplaceOperation => ({
  type: 'ReplaceOperation',
  path,
  item,
});

export const filter = (path: string, predicatePath: string): FilterOperation => ({
  type: 'FilterOperation',
  path,
  predicatePath,
});

export const Operations = {
  find,
  insert,
  replace,
  filter,
  apply,
  applyAll,
};
