import { createButtonCommandDesc } from '../commands/commandFactories';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';

export const insertConjugation = createButtonCommandDesc({
  icon: 'translate',
  description: 'Conjugation',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.conjugation(), { at });
  },
});
