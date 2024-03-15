import React from 'react';
import { Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';


export const insertGraph = createButtonCommandDesc({
  icon: <i className="fa-solid fa-calculator"></i>,
  category: 'Media',
  description: 'Graph',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.graph(''), { at });
  },
});
