import { Editor, Element, Transforms } from 'slate';
import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';

const ui = {
  icon: 'code',
  description: 'ECL REPL',
};

export const insertEcl = createButtonCommandDesc({
  ...ui,
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, Model.ecl(), { at: editor.selection });
  },
  precondition: (editor) => !isActive(editor, 'table'),
});
