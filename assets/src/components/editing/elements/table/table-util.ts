import * as ContentModel from 'data/content/model/elements/types';

/**
 * Given a set of model properties, returns a map of the appropriate
 * attributes to set on a <td> or <th> element.
 *
 */
export const cellAttributes = (attrs: ContentModel.TableCell, additionalClass = '') => {
  return {
    className: attrs.align
      ? `text-${attrs.align} ${additionalClass}`
      : additionalClass == ''
      ? undefined
      : additionalClass,
    colSpan: attrs.colspan || undefined,
    rowSpan: attrs.rowspan || undefined,
  };
};

export const getColspan = (cell: ContentModel.TableCell): number => cell.colspan || 1;
export const getRowspan = (cell: ContentModel.TableCell): number => cell.rowspan || 1;

const getRowColspan = (row: ContentModel.TableRow): number => {
  return row.children.reduce((sum, cell) => sum + getColspan(cell), 0);
};

/**
 * Given a Table, with cells that may have colspan / rowspan attributes,
 * return a 2 dimensional array that represents what cells would be in which position.
 * TableCells with spans will appear in more than one entry.
 *
 * A table such as:
 * <tr><td colspan="2">A</td><td rowspan="2">B</td></tr>
 * <tr><td>C</td><td>D</td></tr>
 *
 * Would make a grid like:
 *
 * [ A ] [ A ] [ B ]
 * [ C ] [ D ] [ B ]
 *
 * Notice how the "A" and "B" td's are in multiple grid positions.
 * (Note, the labels in that grid are for illustrative purposes, the actual TableCell object will be in the
 *  returned value)
 *
 */
export const getVisualGrid = (table: ContentModel.Table): ContentModel.TableCell[][] => {
  const maxColumns = table.children.reduce((max, row) => Math.max(max, getRowColspan(row)), 0);

  const grid: ContentModel.TableCell[][] = Array(table.children.length)
    .fill(null)
    .map(() => Array(maxColumns).fill(null));

  for (let rowIndex = 0; rowIndex < table.children.length; rowIndex++) {
    const row = table.children[rowIndex];
    for (const cell of row.children) {
      const firstNullIndex = grid[rowIndex].findIndex((cell) => cell === null);
      // On this row, we start at the first null index, and fill in the cells

      const colspan = getColspan(cell);
      const rowspan = getRowspan(cell);
      const startColIndex = firstNullIndex;
      const endColIndex = firstNullIndex + colspan - 1;

      for (let j = 0; j < rowspan; j++) {
        for (let i = startColIndex; i <= endColIndex; i++) {
          const targetRowIndex = rowIndex + j;
          if (grid.length > targetRowIndex && grid[targetRowIndex].length > i) {
            // If statement is so we can handle rowspans (or colsspans) that are too big
            grid[targetRowIndex][i] = cell;
          }
        }
      }
    }
  }

  // We remove any null cells so irregular tables are handled correctly
  const gridWithoutNulls = grid.map((row) => row.filter((cell) => cell !== null));

  return gridWithoutNulls;
};
