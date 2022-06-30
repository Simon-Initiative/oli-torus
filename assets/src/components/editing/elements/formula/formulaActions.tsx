import { Transforms } from 'slate';

import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';

export const insertFormula = createButtonCommandDesc({
  icon: 'functions',
  description: 'Formula',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.formula(), { at });
  },
});

export const insertInlineFormula = createButtonCommandDesc({
  icon: 'functions',
  description: 'Formula',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.formulaInline(), { at });
  },
});
