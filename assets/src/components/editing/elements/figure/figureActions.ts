import { Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { insideSemanticElement } from '../utils';

export const insertFigure = createButtonCommandDesc({
  icon: 'note',
  description: 'Figure',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.figure(), { at });
  },
  precondition: (editor) => !insideSemanticElement(editor),
});
