import { getVisualGrid } from '../../../src/components/editing/elements/table/table-util';
import { Table } from '../../../src/data/content/model/elements/types';
import { generateRow, testGridIds } from './table-test-util';

describe('Table cell merging', () => {
  describe('getVisualGrid', () => {
    it('should return a grid of cells', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ id: 'a' }, { id: 'b' }, { id: 'c' }]),
          generateRow([{ id: 'e' }, { id: 'f' }, { id: 'g' }]),
        ],
      };
      const grid = getVisualGrid(table);

      testGridIds(grid, [
        ['a', 'b', 'c'],
        ['e', 'f', 'g'],
      ]);

      expect(grid.length).toEqual(2);
      expect(grid[0].length).toEqual(3);
      expect(grid[1].length).toEqual(3);
    });

    it('should respect colspan of cells', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ id: 'a', colspan: 2 }, { id: 'b' }, { id: 'c', colspan: 4 }]),
          generateRow([{ colspan: 5, id: 'e' }, { id: 'f' }, { id: 'g' }]),
        ],
      };
      const grid = getVisualGrid(table);

      testGridIds(grid, [
        ['a', 'a', 'b', 'c', 'c', 'c', 'c'],
        ['e', 'e', 'e', 'e', 'e', 'f', 'g'],
      ]);

      expect(grid.length).toEqual(2);
      expect(grid[0][0]).toBe(grid[0][1]);
      expect(grid[1][0]).toBe(grid[1][1]);
      expect(grid[1][0]).toBe(grid[1][3]);
      expect(grid[0].length).toEqual(7);
      expect(grid[1].length).toEqual(7);
    });

    it('should respect rowspan of cells', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ rowspan: 2, id: 'a' }, { id: 'b' }, { id: 'c' }]),
          generateRow([{ id: 'e' }, { id: 'f' }]),
        ],
      };
      const grid = getVisualGrid(table);

      testGridIds(grid, [
        ['a', 'b', 'c'],
        ['a', 'e', 'f'],
      ]);

      expect(grid.length).toEqual(2);
      expect(grid[0].length).toEqual(3);
      expect(grid[1].length).toEqual(3);
      expect(grid[0][0]).toBe(grid[1][0]);
    });

    it('should respect rowspan of cells at end', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([{}, {}, { rowspan: 2 }]), generateRow([{}, {}])],
      };
      const grid = getVisualGrid(table);

      expect(grid.length).toEqual(2);
      expect(grid[0].length).toEqual(3);
      expect(grid[1].length).toEqual(3);

      expect(grid[0][2]).toBe(grid[1][2]);
    });

    it('should respect colspan & rowspan of cells', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ rowspan: 2, colspan: 2, id: 'a' }, { id: 'b' }]),
          generateRow([{ id: 'c' }]),
        ],
      };
      const grid = getVisualGrid(table);

      testGridIds(grid, [
        ['a', 'a', 'b'],
        ['a', 'a', 'c'],
      ]);

      expect(grid.length).toEqual(2);
      expect(grid[0].length).toEqual(3);
      expect(grid[1].length).toEqual(3);
      expect(grid[0][0]).toBe(grid[1][0]);
      expect(grid[0][0]).toBe(grid[1][1]);
      expect(grid[0][0]).toBe(grid[0][1]);
    });

    it('should handle rowspans that are too big', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([{ rowspan: 3, id: 'a' }, { id: 'b' }]), generateRow([{ id: 'c' }])],
      };
      const grid = getVisualGrid(table);

      testGridIds(grid, [
        ['a', 'b'],
        ['a', 'c'],
      ]);

      expect(grid.length).toEqual(2);
      expect(grid[0].length).toEqual(2);
      expect(grid[1].length).toEqual(2);
      expect(grid[0][0]).toBe(grid[1][0]);
    });

    it('should handle poorly formatted tables that are not rectangular', () => {
      // This should rarely happen because the table normalizer will fix it.
      // It may be possible the first time an editor is opened on an imported lesson.
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([]), generateRow([{}, {}, {}]), generateRow([{}])],
      };
      const grid = getVisualGrid(table);
      expect(grid.length).toEqual(3);
      expect(grid[0].length).toEqual(0);
      expect(grid[1].length).toEqual(3);
      expect(grid[2].length).toEqual(1);
    });
  });
});
