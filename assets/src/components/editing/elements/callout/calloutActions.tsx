import { Model } from '../../../../data/content/model/elements/factories';
import { insideSemanticElement } from '../utils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import React from 'react';
import { Transforms } from 'slate';

export const insertCallout = createButtonCommandDesc({
  icon: <i className="fa-solid fa-bullhorn"></i>,
  description: 'Callout',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.callout(), { at, select: true });
  },
  precondition: (editor) => !insideSemanticElement(editor),
});

export const insertInlineCallout = createButtonCommandDesc({
  icon: <i className="fa-solid fa-bullhorn"></i>,
  description: 'Callout',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.wrapNodes(editor, Model.calloutInline(), { at, split: true });
  },
});
