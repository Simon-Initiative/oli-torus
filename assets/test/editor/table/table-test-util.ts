import { TableCell, TableRow } from '../../../src/data/content/model/elements/types';

interface CellShorthand {
  colspan?: number;
  rowspan?: number;
  id?: string;
}
/** Helper function for generating test data. */
export const generateRow = (cells: CellShorthand[]): TableRow => {
  return {
    type: 'tr',
    id: 'X',
    children: cells.map((cell) => {
      return {
        type: 'td',
        id: cell.id || 'C',
        children: [],
        ...cell,
      };
    }),
  };
};

// Helper function to quicly compare a generated grid from getVisualGrid with a
// grid of id's we expect to see in the output
export const testGridIds = (grid: TableCell[][], ids: string[][]) => {
  expect(grid.length).toEqual(ids.length);
  for (let i = 0; i < grid.length; i++) {
    expect(grid[i].length).toEqual(ids[i].length);
    for (let j = 0; j < grid[i].length; j++) {
      expect(grid[i][j].id).toEqual(ids[i][j]);
    }
  }
};
