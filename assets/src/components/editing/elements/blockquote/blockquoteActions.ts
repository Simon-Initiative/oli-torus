import { Transforms, Editor, Element } from 'slate';
import { isTopLevel, isActive } from 'components/editing/utils';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';

export const toggleBlockquote = createButtonCommandDesc({
  icon: 'format_quote',
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
