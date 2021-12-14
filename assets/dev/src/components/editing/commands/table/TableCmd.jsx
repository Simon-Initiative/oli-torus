import { Transforms } from 'slate';
import { td, tr, table } from 'data/content/model/elements/factories';
import { SizePicker } from 'components/editing/commands/table/SizePicker';
import { isTopLevel } from 'components/editing/utils';
const command = {
    execute: (_context, editor, params) => {
        const at = editor.selection;
        if (!at)
            return;
        const rows = [];
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
    precondition: (editor) => {
        return isTopLevel(editor);
    },
    // eslint-disable-next-line
    obtainParameters: (_context, _editor, onDone, onCancel) => {
        // eslint-disable-next-line
        return <SizePicker onTableCreate={(rows, columns) => onDone({ rows, columns })}/>;
    },
};
export const commandDesc = {
    type: 'CommandDesc',
    icon: () => 'grid_on',
    description: () => 'Table',
    command,
};
//# sourceMappingURL=TableCmd.jsx.map