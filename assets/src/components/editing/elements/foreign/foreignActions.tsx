import { Model } from '../../../../data/content/model/elements/factories';
import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import React from 'react';
import { Element, Transforms } from 'slate';

export const insertForeign = createButtonCommandDesc({
  icon: <i className="fa-solid fa-language"></i>,
  description: 'Foreign',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    if (isActive(editor, 'foreign')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'foreign',
      });
    }

    Transforms.wrapNodes(editor, Model.foreign(), { at, split: true });
  },
  precondition: (_editor) => true,
});
