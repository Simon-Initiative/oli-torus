import { insideSemanticElement } from '../utils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import React from 'react';
import { Transforms } from 'slate';

export const insertDefinition = createButtonCommandDesc({
  icon: <i className="fa-solid fa-book-open"></i>,
  description: 'Definition',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;
    Transforms.insertNodes(editor, Model.definition(), { at });
  },
  precondition: (editor) => !insideSemanticElement(editor),
});
