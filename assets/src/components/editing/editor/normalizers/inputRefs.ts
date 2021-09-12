import { ReactEditor } from 'slate-react';
import { Transforms, Node, Path } from 'slate';
import * as ContentModel from 'data/content/model';

export const normalize = (editor: ReactEditor, node: Node, path: Path) => {
  if (node.type === 'table') {
    // Ensure that the number of cells in each row is the same

    // First get max count of cells in any row, and see if any rows
    // have a different amount of cells.
    let max = -1;
    let anyDiffer = false;
    (node.children as any).forEach((row: Node) => {
      const children = row.children as any;
      const count = children.length;

      if (max === -1) {
        max = count;
      } else if (count !== max) {
        anyDiffer = true;

        if (count > max) {
          max = count;
        }
      }
    });

    if (anyDiffer) {
      (node.children as any).forEach((row: Node, index: number) => {
        const children = row.children as any;
        let count = children.length;

        // Get a path to the first td element in this row
        const thisPath = [...path, index, 0];

        // Add as many empty td elements to bring this row back up to
        // the max td count
        while (count < max) {
          Transforms.insertNodes(editor, ContentModel.td(''), { at: thisPath });
          count = count + 1;
        }
      });
    }
  }
};
