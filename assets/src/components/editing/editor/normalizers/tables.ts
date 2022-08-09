import { Transforms, Path, Editor, Element } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { ModelElement, Table, TableCell, TableRow } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';

/**
 * Given an array of columns that may or may not have colspan set, sum up the total
 * col span
 **/
export const getColumnSpan = (cells: TableCell[]): number =>
  cells.reduce((acc, curr) => acc + (curr.colspan || 1), 0);

/**
 * Returns the effective number of columns for a table row. This is how many "slots" are taken
 * up in the row, even if there are fewer cells. So, if you had a single column with a colspan of
 * 5, this will return 5.
 *
 * If you had a row before it with rowspan = 2, we'll include that column in this row.
 *
 */
export const getEffectiveColumns = (row: TableRow, table: Table): number => {
  const rowIndex = table.children.indexOf(row);
  if (rowIndex === -1) {
    console.error("Tried to getEffectiveColumns for a row that doesn't belong to the table");
    return 0;
  }

  // First, find all the rows before this oen.
  const previousRows = table.children.slice(0, rowIndex);
  // Then, find all the columns that are in those rows that stray into this one

  const previousRowColumnSpan = previousRows.reduce(
    (spanAmount: number, row: TableRow, index: number) => {
      const overlappingCells = row.children.filter((cell: TableCell) => {
        const rowspan = cell.rowspan || 1;
        // The row overlaps with our test row if the index of the row plus the rowspan of the cell
        // is greater than the index of our target row. (Greater than because rowspan=1 means it doesn't
        // span rows)
        return index + rowspan > rowIndex;
      });
      return spanAmount + getColumnSpan(overlappingCells);
    },
    0,
  );

  return getColumnSpan(row.children) + previousRowColumnSpan;
};

export const normalize = (editor: Editor, table: ModelElement | FormattedText, path: Path) => {
  if (Element.isElement(table) && table.type === 'table') {
    // Ensure that the number of effective cells in each row is the same
    // First get max count of cells in any row, and see if any rows
    // have a different amount of cells.
    //
    // colspan and rowspan make this operation more complicated since a cell might take up more than one slot
    // in a row via colspan, or a cell from a previous row might take up one or more slots in the current row
    // via rowspan.

    let max = -1;
    let anyDiffer = false;
    table.children.forEach((row) => {
      const count = getEffectiveColumns(row, table);

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
      console.warn('Normalizing table');
      table.children.forEach((row, index: number) => {
        let count = getEffectiveColumns(row, table);

        // Get a path to the last td element in this row
        const thisPath = [...path, index, row.children.length];

        // Add as many empty td elements to bring this row back up to
        // the max td count
        while (count < max) {
          console.warn(`Adding element to row index=${index} count=${count} max=${max}`);
          Transforms.insertNodes(editor, Model.td(''), { at: thisPath });
          count = count + 1;
        }
      });
    }
  }
};
