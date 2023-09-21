import React from 'react';
import { Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import { insideSemanticElement } from '../utils';

export const insertFigure = createButtonCommandDesc({
  icon: <i className="fa-solid fa-note-sticky"></i>,
  description: 'Figure',
  category: 'STEM',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.figure(), { at });
  },
  precondition: (editor) => !insideSemanticElement(editor),
});
