import { ReactEditor } from 'slate-react';
import { CommandDesc, Command } from 'components/editor/commands/interfaces';
import { Transforms } from 'slate';
import { td, tr, table } from 'data/content/model';
import { SizePicker } from './SizePicker';

// The UI command for creating tables
const command: Command = {
  execute: (context: any, editor: ReactEditor, params: any) => {

    const rows: any = [];

    for (let i = 0; i < params.rows; i += 1) {
      const tds = [];
      for (let j = 0; j < params.columns; j += 1) {
        tds.push(td(''));
      }
      rows.push(tr(tds));
    }

    const t = table(rows);
    Transforms.insertNodes(editor, t);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },

  obtainParameters: (editor: ReactEditor,
    onDone: (params: any) => void, onCancel: () => void) => {

    return <SizePicker onHide={onCancel}
      onTableCreate={(rows, columns) => onDone({ rows, columns })} />;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'grid_on',
  description: () => 'Table',
  command,
};
