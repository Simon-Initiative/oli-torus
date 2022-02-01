import { Model } from 'data/content/model/elements/factories';
import { Editor, Element, Transforms } from 'slate';

export const switchType = (editor: Editor, type: any) => {
  const [topLevel, at] = [...Editor.nodes(editor)][1];
  if (!Element.isElement(topLevel)) return;

  const headings = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
  const lists = ['ul', 'ol'];
  const canonicalize = () => {
    // Convert element to a list of paragraphs
    switch (true) {
      case headings.includes(topLevel.type):
        return Transforms.setNodes(editor, { type: 'p' }, { at });
      case topLevel.type === 'p':
        return;
      case lists.includes(topLevel.type):
        Transforms.setNodes(
          editor,
          { type: 'p' },
          {
            at,
            mode: 'all',
            match: (e) => Element.isElement(e) && e.type === 'li',
          },
        );
        Transforms.unwrapNodes(editor, {
          at,
          mode: 'all',
          match: (e) => Element.isElement(e) && ['ul', 'ol'].includes(e.type),
        });
        return;
      case topLevel.type === 'blockquote':
        return Transforms.unwrapNodes(editor, { at });
      default:
        return;
    }
  };

  const convert = () => {
    if (!editor.selection) return;
    switch (true) {
      case headings.includes(type):
        return Transforms.setNodes(editor, { type }, { at: editor.selection });
      case type === 'p':
        return;
      case lists.includes(type):
        Transforms.setNodes(
          editor,
          { type: 'li' },
          { match: (e) => Element.isElement(e) && e.type === 'p', mode: 'all' },
        );
        return Transforms.wrapNodes(editor, Model.ul(), {
          match: (e) => Element.isElement(e) && e.type === 'li',
          mode: 'all',
        });
      case type === 'blockquote':
        return Transforms.wrapNodes(editor, Model.blockquote(), {
          match: (e) => Element.isElement(e) && e.type === 'p',
        });
      default:
        return;
    }
  };
  Editor.withoutNormalizing(editor, () => {
    canonicalize();
    convert();
  });
};
