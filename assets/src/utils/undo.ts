import jp from 'jsonpath';

export type InsertOperation = {
  path: string;
  index: number;
  item: Record<string, unknown>;
}

export function applyOperations(json: Record<string, any>, ops: InsertOperation[]) : void {
  ops.forEach((op) => {
    jp.apply(json, op.path, function(result) {
      result.splice(op.index, 0, op.item);
      return result;
    });
  });
}

