import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';

const ui = {
  icon: <i className="fa-solid fa-code"></i>,
  description: 'Code (Block)',
};

export const insertCodeblock = createButtonCommandDesc({
  ...ui,
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, Model.code(), { at: editor.selection });
  },
  precondition: (editor) => !isActive(editor, 'table'),
});

export const toggleCodeblock = createButtonCommandDesc({
  ...ui,
  active: (editor) => isActive(editor, 'code'),
  execute: (_ctx, editor) => switchType(editor, 'code'),
});

export const codeLanguageDesc = (editor: Editor) => {
  const [topLevel] = [...Editor.nodes(editor)][1];
  const lang = Element.isElement(topLevel) && topLevel.type === 'code' ? topLevel.language : 'Text';

  return createButtonCommandDesc({
    icon: <i className="fa-solid fa-code"></i>,
    description: lang,
    active: (_editor) => false,
    execute: (_ctx, _editor) => {},
  });
};
