import { CommandDesc, Command } from 'components/editing/commands/interfaces';
import { Editor, Transforms } from 'slate';
import { td, tr, table } from 'data/content/model/elements/factories';
import { SizePicker } from 'components/editing/commands/table/SizePicker';
import { isTopLevel } from 'components/editing/utils';

const command: Command = {
  execute: (_context: any, editor: Editor, params: any) => {
    const at = editor.selection;
    if (!at) return;
    const rows: any = [];

    for (let i = 0; i < params.rows; i += 1) {
      const tds = [];
      for (let j = 0; j < params.columns; j += 1) {
        tds.push(td(''));
      }
      rows.push(tr(tds));
    }

    const t = table(rows);
    Transforms.insertNodes(editor, t, { at });
    Transforms.deselect(editor);
  },
  precondition: (editor: Editor) => {
    return isTopLevel(editor);
  },
  // eslint-disable-next-line
  obtainParameters: (_context, _editor, onDone, onCancel) => {
    // eslint-disable-next-line
    return <SizePicker onTableCreate={(rows, columns) => onDone({ rows, columns })} />;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'grid_on',
  description: () => 'Table',
  command,
};
