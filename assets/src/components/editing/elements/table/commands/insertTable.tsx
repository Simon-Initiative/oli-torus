import { Editor, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { isTopLevel } from 'components/editing/utils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';

export const insertTable = createButtonCommandDesc({
  icon: 'grid_on',
  description: 'Table',
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
      for (let j = 0; j < params.columns; j += 1) tds.push(Model.td(''));
      rows.push(Model.tr(tds));
    }

    const t = Model.table(rows);
    Transforms.insertNodes(editor, t, { at });
    Transforms.deselect(editor);
  },
  precondition: (editor: Editor) => isTopLevel(editor),
});
