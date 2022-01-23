import { Editor, Element, Transforms } from 'slate';
import { isActive } from '../../utils';
import { code } from 'data/content/model/elements/factories';
import { createButtonCommandDesc, switchType } from 'components/editing/elements/commands/commands';

const ui = {
  icon: 'code',
  description: 'Code (Block)',
};

export const codeBlockInsertDesc = createButtonCommandDesc({
  ...ui,
  execute: (_context, editor) => {
    if (!editor.selection) return;
    Transforms.insertNodes(editor, code(), { at: editor.selection });
  },
  precondition: (editor) => {
    return !isActive(editor, 'table');
  },
});

export const codeBlockToggleDesc = createButtonCommandDesc({
  ...ui,
  active: (editor) => isActive(editor, 'code'),
  execute: (_ctx, editor) => switchType(editor, 'code'),
});

export const codeLanguageDesc = (editor: Editor) => {
  const [topLevel, at] = [...Editor.nodes(editor)][1];
  const lang = Element.isElement(topLevel) && topLevel.type === 'code' ? topLevel.language : 'Text';

  return createButtonCommandDesc({
    icon: '',
    description: lang,
    active: (_editor) => false,
    execute: (_ctx, _editor) => {},
  });
};
