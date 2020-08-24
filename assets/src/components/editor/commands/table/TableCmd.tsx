import { ReactEditor } from 'slate-react';
import { CommandDesc, Command } from 'components/editor/commands/interfaces';
import { Transforms, Editor, Node } from 'slate';
import { td, tr, table, Paragraph } from 'data/content/model';
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
    if (!editor.selection) return;
    console.log('next', Editor.after(editor, editor.selection));
    Transforms.insertNodes(editor, t);
    Editor
  },
  precondition: (editor: ReactEditor) => {
    //


    if (!editor.selection) {
      return false;
    }
    // Must be toplevel and inside paragraph node
    const nodes = Array.from(Editor.nodes(editor, { at: editor.selection }));
    console.log('nodes', nodes)
    // Only allow table insertion when inside a paragraph at the top-level
    if (nodes.length < 2) {
      return false;
    }
    const parent = nodes[1];
    const grandParent = nodes[0];
    return parent && grandParent && Editor.isEditor(grandParent[0]) && parent[0].type === 'p'

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
