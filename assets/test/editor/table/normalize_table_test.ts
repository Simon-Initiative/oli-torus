import { Model } from 'data/content/model/elements/factories';
import { getEffectiveColumns } from '../../../src/components/editing/editor/normalizers/tables';
import { Table } from '../../../src/data/content/model/elements/types';
import { expectAnyEmptyParagraph, expectAnyId, runNormalizer } from '../normalize-test-utils';
import { generateRow } from './table-test-util';

describe('Table normalization', () => {
  describe('getEffectiveColumns', () => {
    it('should not error on row not in table', () => {
      const error = jest.spyOn(console, 'error').mockImplementation((...args) => {});
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([{}, {}, {}])],
      };
      const row = generateRow([{}, {}, {}]);
      error.mockRestore();
      expect(getEffectiveColumns(row, table)).toEqual(0);
    });

    it('should return the correct number of columns for basic cells', () => {
      // No colspan/rowspan entries
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([{}, {}, {}])],
      };
      expect(getEffectiveColumns(table.children[0], table)).toEqual(3);
    });

    it('should return the correct number of columns considering colspan attributes', () => {
      // Single row, with 3 cells, with colspans 1,2,3
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [generateRow([{ colspan: 1 }, { colspan: 2 }, { colspan: 3 }])],
      };
      const row = table.children[0];

      expect(getEffectiveColumns(row, table)).toEqual(6);
    });

    it('should return the correct number of columns considering rowspan attributes', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ rowspan: 1 }, { rowspan: 4 }, {}]), // Only rowspan4 will affect our last row
          generateRow([{ rowspan: 2 }, {}, {}]), // None of these will affect our last row
          generateRow([{}, {}, { rowspan: 2 }]), // This will affect our last row
          generateRow([{}, {}, {}]),
        ],
      };
      const row = table.children[3];

      // So.. row 1 contributes 1, row 2 contributes 0, row 3 contributes 1, row 4 contributes 3
      expect(getEffectiveColumns(row, table)).toEqual(5);
    });

    it('should return the correct number of columns considering rowspan AND colspan attributes', () => {
      const table: Table = {
        type: 'table',
        id: 'T',
        children: [
          generateRow([{ rowspan: 1 }, { rowspan: 2, colspan: 2 }, { rowspan: 2 }]), // Only rowspan2 will affect our last row
          generateRow([{ colspan: 3 }, {}, {}]),
        ],
      };
      const row = table.children[1];

      // Row 1 has 2 overlapping cells with colspans 2 & 1 contributing 3 total to the last row
      // which has colspans 3,1,1 for a total of 3+1+1+3=8
      expect(getEffectiveColumns(row, table)).toEqual(8);
    });
  });

  it('should add missing cells to rows', () => {
    const original = [
      Model.p(),
      Model.table([
        Model.tr([Model.td('0')]),
        Model.tr([Model.td('A'), Model.td('B')]),
        Model.tr([Model.td('1')]),
      ]),
      Model.p(),
    ];
    const expected = expectAnyId([
      expectAnyEmptyParagraph,
      Model.table([
        Model.tr([Model.td('0'), Model.td('')]),
        Model.tr([Model.td('A'), Model.td('B')]),
        Model.tr([Model.td('1'), Model.td('')]),
      ]),
      expectAnyEmptyParagraph,
    ]);
    const { editor } = runNormalizer(original as any);
    expect(editor.children).toEqual(expected);
  });
});
