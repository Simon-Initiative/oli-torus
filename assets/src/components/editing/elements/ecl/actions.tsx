import React from 'react';
import { Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import { isActive } from '../../slateUtils';

const ui = {
  icon: <i className="fa-solid fa-code"></i>,
  description: 'ECL Code Editor',
};

export const insertEcl = createButtonCommandDesc({
  ...ui,
  category: 'STEM',
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, Model.ecl(), { at: editor.selection });
  },
  precondition: (editor) => !isActive(editor, 'table'),
});
