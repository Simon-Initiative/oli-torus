/*
  Functions relating to the merging and splitting of cells in tables in the slateJS editor.
*/

import { Transforms, Editor, Element, Path } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';
import { Table, TableCell, TableRow } from '../../../../data/content/model/elements/types';
import { getColspan, getRowspan, getVisualGrid } from './table-util';

/**
 * This function will return a list of TableCell entries that are visually next to each other
 * in a given row. This can be useful when merging cells to the right to figure out which cells are
 * actually to the right of the merged cell.
 */
export const getCellsInRow = (table: Table, rowIndex: number): TableCell[] => {
  const grid = getVisualGrid(table);
  return grid[rowIndex];
};

const getRowData = (editor: Editor) => {
  const [tableEntry] = Editor.nodes<Table>(editor, {
    match: (n) => Element.isElement(n) && n.type === 'table',
  });
  const [rowEntry] = Editor.nodes<TableRow>(editor, {
    match: (n) => Element.isElement(n) && n.type === 'tr',
  });
  const [cellEntry] = Editor.nodes<TableCell>(editor, {
    match: (n) => Element.isElement(n) && (n.type === 'th' || n.type === 'td'),
  });

  if (!tableEntry || !rowEntry || !cellEntry) {
    return { table: null, row: null, cell: null };
  }

  const [table, tablePath] = tableEntry;
  const [row, rowPath] = rowEntry;
  const [cell, cellPath] = cellEntry;

  return { table, row, cell, tablePath, rowPath, cellPath };
};

export const canExpandCellRight = (editor: Editor) => {
  try {
    const { table, cell, row } = getRowData(editor);

    if (!table || !row || !cell) {
      return false;
    }

    const rowIndex = table.children.indexOf(row);
    const cells = getCellsInRow(table, rowIndex);
    const cellIndex = cells.indexOf(cell);
    const nextCell = cells[cellIndex + 1];

    return (
      cellIndex > -1 && // We found the cell in our list
      nextCell && // There is a cell to the right of this one
      getRowspan(cell) === getRowspan(nextCell) && // The rowspan of the cell to the right is the same as this one
      row.children.includes(nextCell) // That next cell is actually in this row, and not spanning into it
    );
  } catch (e) {
    console.warn('table-cell-operations::canExpandCellRight', e);
  }
};

export const canSplitCell = (editor: Editor) => {
  try {
    const [cellEntry] = Editor.nodes<TableCell>(editor, {
      match: (n) => Element.isElement(n) && (n.type === 'th' || n.type === 'td'),
    });
    if (!cellEntry) return false;
    const [cell] = cellEntry;
    return getColspan(cell) > 1 || getRowspan(cell) > 1;
  } catch (e) {
    console.warn('table-cell-operations::canSplitCell', e);
    return false;
  }
};

export const splitCell = (editor: Editor) => {
  const [cellEntry] = Editor.nodes<TableCell>(editor, {
    match: (n) => Element.isElement(n) && (n.type === 'th' || n.type === 'td'),
  });
  if (!cellEntry) return false;
  const [cell, cellPath] = cellEntry;

  const originalColspan = getColspan(cell);
  const originalRowspan = getRowspan(cell);

  Editor.withoutNormalizing(editor, () => {
    Transforms.setNodes(
      editor,
      {
        colspan: 1,
        rowspan: 1,
      },
      { at: cellPath },
    );

    // Insert empty cells in the current row to fill in missing spots.
    const rowDestination = [...cellPath];
    rowDestination[rowDestination.length - 1]++;
    for (let i = 1; i < originalColspan; i++) {
      Transforms.insertNodes(editor, Model.td(''), { at: rowDestination });
    }

    // Insert empty cells in the later rows to fill in missing spots.
    const colDestination = [...cellPath];
    for (let i = 1; i < originalRowspan; i++) {
      colDestination[colDestination.length - 2]++;
      Transforms.insertNodes(editor, Model.td(''), { at: colDestination });
    }
  });
};

export const expandCellRight = (editor: Editor) => {
  // #1 Grab the cell to the right of the current cell
  // #2 Delete that cell
  // #3 Modify our cell contents to include that cell contents
  // #4 Add 1 to our colspan

  const { table, cell, row, cellPath } = getRowData(editor);

  if (!table || !row || !cell) {
    return false;
  }

  const rowIndex = table.children.indexOf(row);
  const cells = getCellsInRow(table, rowIndex);
  const cellIndex = cells.indexOf(cell);
  const nextCell = cells[cellIndex + 1];

  Editor.withoutNormalizing(editor, () => {
    Transforms.setNodes(
      editor,
      {
        colspan: getColspan(cell) + 1,
      },
      { at: cellPath },
    );
    const destination = [...cellPath, Math.max(0, cell.children.length)];
    Transforms.insertNodes(editor, nextCell.children, { at: destination });
    Transforms.delete(editor, { at: Path.next(cellPath) });
  });
};

export const canExpandDown = (editor: Editor) => {
  try {
    const { table, cell, row } = getRowData(editor);

    if (!table || !row || !cell) {
      return false;
    }

    const grid = getVisualGrid(table);
    const nextCell = findCellDown(grid, cell);
    return !!nextCell && getColspan(cell) === getColspan(nextCell);
  } catch (e) {
    console.warn('table-cell-operations::canExpandDown', e);
    return false;
  }
};

/**
 * Curried function that removes a cell from a TableRow and returns a new TableRow
 *
 * removeCell(cellToDelete)(row) => a new row with that cell removed
 *
 * Probably most useful in map calls...  row.map(removeCell(cell))
 */
const removeCell =
  (cellToRemove: TableCell) =>
  (row: TableRow): TableRow => ({
    ...row,
    children: row.children.filter((cell) => cell !== cellToRemove),
  });

/**
 * Curried function that replaces one cell with another in a TableRow
 *
 * replaceCell(oldCell, newCell)(row) => a new row with that cell replaced
 *
 * Probably most useful in map calls...  row.map(replaceCell(oldCell, newCell))
 */
const replaceCell =
  (cellToReplace: TableCell, newCell: TableCell) =>
  (row: TableRow): TableRow => ({
    ...row,
    children: row.children.map((cell) => (cell == cellToReplace ? newCell : cell)),
  });

/**
 * Finds a TableCell visually below the given cell.
 *
 */
export const findCellDown = (grid: TableCell[][], cell: TableCell) => {
  for (let rowIndex = 0; rowIndex < grid.length; rowIndex++) {
    const row = grid[rowIndex];
    const cellIndex = row.indexOf(cell);
    if (cellIndex === -1) continue; // Our cell isn't in this row

    // This is the first occurence of the cell we've found. We need to check down now.
    for (let i = rowIndex + 1; i < grid.length; i++) {
      const nextRow = grid[i];
      const nextCell = nextRow[cellIndex];
      if (nextCell !== cell) {
        // While moving down the grid, we found a cell that isn't the same as our cell, so it's the next one down.
        return nextCell;
      }
    }

    // We went to the bottom of the grid and didn't find another cell, so there isn't one.
    return null;
  }
};

/**
 * Given a Table and a TableCell, returns a brand new Table that would result from
 * merging that cell down into the cell below it.
 *
 */
export const calculateExpandDown = (table: Table, cell: TableCell) => {
  const grid = getVisualGrid(table);
  const nextCell = findCellDown(grid, cell);
  if (!nextCell) return;

  if (!Element.isElement(nextCell)) return;
  if (nextCell.type !== 'td' && nextCell.type !== 'th') return;

  const newCell = {
    ...cell,
    rowspan: getRowspan(cell) + 1,
    children: [...cell.children, ...nextCell.children],
  };
  console.info({ cell, newCell });
  return {
    ...table,
    children: table.children.map(removeCell(nextCell)).map(replaceCell(cell, newCell)),
  };
};

export const expandCellDown = (editor: Editor) => {
  const { table, cell, row, tablePath } = getRowData(editor);

  if (!table || !row || !cell) {
    return false;
  }

  const newTable = calculateExpandDown(table, cell);
  if (!newTable) return false;

  /**
   * To make finding all the elements easier, we grab the table model, make all the modifications to it
   * outside of the editor, then replace the old table with the new one.
   */
  Editor.withoutNormalizing(editor, () => {
    Transforms.delete(editor, { at: tablePath });
    Transforms.insertNodes(editor, newTable, { at: tablePath });
  });
};
