import React from 'react';
import { Model } from 'data/content/model/elements/factories';
import { Element, Transforms } from 'slate';
import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from '../commands/commandFactories';

export const popupCmdDesc = createButtonCommandDesc({
  icon: <i className="fa-solid fa-window-restore"></i>,
  description: 'Popup Content',
  execute: (_context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    if (isActive(editor, 'popup')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'popup',
      });
    }

    Transforms.wrapNodes(editor, Model.popup(), { split: true });
  },

  active: (e) => isActive(e, 'popup'),
});
