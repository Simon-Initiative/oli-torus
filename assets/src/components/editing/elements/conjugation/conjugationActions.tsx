import React from 'react';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';
import { createButtonCommandDesc } from '../commands/commandFactories';

export const insertConjugation = createButtonCommandDesc({
  icon: <i className="fa-solid fa-language"></i>,
  description: 'Conjugation',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.conjugation(), { at });
  },
});
