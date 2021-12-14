import { Transforms, Node, Path, Editor, Element } from 'slate';
import { td } from 'data/content/model/elements/factories';

export const normalize = (editor: Editor, node: Node, path: Path) => {
  if (Element.isElement(node) && node.type === 'table') {
    // Ensure that the number of cells in each row is the same

    // First get max count of cells in any row, and see if any rows
    // have a different amount of cells.
    let max = -1;
    let anyDiffer = false;
    node.children.forEach((row) => {
      const children = row.children;
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
      node.children.forEach((row, index: number) => {
        const children = row.children;
        let count = children.length;

        // Get a path to the first td element in this row
        const thisPath = [...path, index, 0];

        // Add as many empty td elements to bring this row back up to
        // the max td count
        while (count < max) {
          Transforms.insertNodes(editor, td(''), { at: thisPath });
          count = count + 1;
        }
      });
    }
  }
};
