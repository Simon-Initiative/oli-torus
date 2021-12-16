import { Transforms } from 'slate';
import { isActive } from '../utils';
import { code } from 'data/content/model/elements/factories';
import { ButtonCommand } from 'components/editing/toolbar/interfaces';
import { toolbarButtonDesc } from 'components/editing/toolbar/commands';

const command: ButtonCommand = {
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, code(), { at: editor.selection });
  },
  precondition: (editor) => {
    return !isActive(editor, 'table');
  },
};

export const commandDesc = toolbarButtonDesc({
  icon: () => 'code',
  description: () => 'Code (```)',
  ...command,
});
