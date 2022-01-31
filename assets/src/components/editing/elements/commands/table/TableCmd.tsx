import { CommandDesc } from 'components/editing/elements/commands/interfaces';
import { Editor, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { SizePicker } from 'components/editing/elements/commands/table/SizePicker';
import { isTopLevel } from 'components/editing/utils';

export const tableCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'grid_on',
  description: () => 'Table',
  command: {
    execute: (
      _context: any,
      editor: Editor,
      params: { rows: number; columns: number } = { rows: 2, columns: 2 },
    ) => {
      const at = editor.selection;
      if (!at) return;
      const rows: any = [];

      for (let i = 0; i < params.rows; i += 1) {
        const tds = [];
        for (let j = 0; j < params.columns; j += 1) {
          tds.push(Model.td(''));
        }
        rows.push(Model.tr(tds));
      }

      const t = Model.table(rows);
      Transforms.insertNodes(editor, t, { at });
      Transforms.deselect(editor);
    },
    precondition: (editor: Editor) => {
      return isTopLevel(editor);
    },
    obtainParameters: (_context, _editor, onDone, _onCancel) => {
      // eslint-disable-next-line
    return <SizePicker onTableCreate={(rows, columns) => onDone({ rows, columns })} />;
    },
  },
};
