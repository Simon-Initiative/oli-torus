import jp from 'jsonpath';

export type UndoOperation = InsertOperation | ReplaceOperation;

export type InsertOperation = {
  type: 'InsertOperation',
  path: string;
  index: number;
  item: Record<string, unknown>;
}

export type ReplaceOperation = {
  type: 'ReplaceOperation',
  path: string;
  item: any;
}

export function applyOperations(json: Record<string, any>, ops: UndoOperation[]) : void {
  ops.forEach((op) => {

    jp.apply(json, op.path, function(result: any) {
      if (op.type === 'InsertOperation') {
        result.splice(op.index, 0, op.item);
        return result;
      } else {
        console.log(op.item);
        return op.item;
      }
    });
  });
}

