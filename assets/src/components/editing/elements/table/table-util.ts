import * as ContentModel from 'data/content/model/elements/types';

/**
 * Given a set of model properties, returns a map of the appropriate
 * attributes to set on a <td> or <th> element.
 *
 */
export const cellAttributes = (attrs: ContentModel.TableHeader | ContentModel.TableData) => {
  return {
    className: attrs.align ? `text-${attrs.align}` : undefined,
    colSpan: attrs.colspan || undefined,
    rowSpan: attrs.rowspan || undefined,
  };
};

export const getColspan = (cell: ContentModel.TableCell): number => cell.colspan || 1;
export const getRowspan = (cell: ContentModel.TableCell): number => cell.rowspan || 1;

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
  const grid: ContentModel.TableCell[][] = Array(table.children.length)
    .fill(null)
    .map(() => []);

  const maxColIndex = table.children.reduce((max, row) => Math.max(max, row.children.length), 0);

  for (let colIndex = 0; colIndex < maxColIndex; colIndex++) {
    for (let rowIndex = 0; rowIndex < table.children.length; rowIndex++) {
      const cell = table.children[rowIndex]?.children[colIndex];
      if (!cell) continue;
      const colspan = getColspan(cell);
      const rowspan = getRowspan(cell);
      for (let i = 0; i < colspan; i++) {
        for (let j = 0; j < rowspan; j++) {
          grid[rowIndex + j] && grid[rowIndex + j].push(cell);
        }
      }
    }
  }

  return grid;
};
