import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';

export const commandDesc = createButtonCommandDesc({
  icon: <i className="fa-solid fa-link"></i>,
  description: 'Link (⌘L)',
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'a')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'a',
      });
    }

    const href = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, Model.link(href), { split: true });
  },
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'a'),
});
