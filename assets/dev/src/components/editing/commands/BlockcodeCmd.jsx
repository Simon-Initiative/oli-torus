import { Transforms } from 'slate';
import { isActive } from '../utils';
import { code } from 'data/content/model/elements/factories';
const command = {
    execute: (_context, editor) => {
        if (!editor.selection)
            return;
        Transforms.insertNodes(editor, code(), { at: editor.selection });
    },
    precondition: (editor) => {
        return !isActive(editor, 'table');
    },
};
export const commandDesc = {
    type: 'CommandDesc',
    icon: () => 'code',
    description: () => 'Code (```)',
    command,
};
//# sourceMappingURL=BlockcodeCmd.jsx.map