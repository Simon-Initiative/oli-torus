import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { isActive, isTopLevel } from 'components/editing/slateUtils';
import { Model } from 'data/content/model/elements/factories';

export const toggleBlockquote = createButtonCommandDesc({
  icon: <i className="fa-solid fa-quote-right"></i>,
  description: 'Quote',
  execute: (_context, editor) => {
    Editor.withoutNormalizing(editor, () => {
      const active = isActive(editor, 'blockquote');
      if (active) {
        return Transforms.unwrapNodes(editor, {
          match: (n) => Element.isElement(n) && n.type === 'blockquote',
        });
      }

      Transforms.setNodes(editor, { type: 'p' });
      Transforms.wrapNodes(editor, Model.blockquote());
    });
  },
  precondition: (editor) =>
    (isTopLevel(editor) && isActive(editor, ['p'])) || isActive(editor, ['blockquote']),
  active: (e) => isActive(e, 'blockquote'),
});
