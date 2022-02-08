import { Model } from 'data/content/model/elements/factories';
import { Editor, Element, Node, Path, Transforms } from 'slate';

const headings = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
const lists = ['ul', 'ol'];

const isHeading = (type: any) => headings.includes(type);
const isList = (type: any) => lists.includes(type);
const isBlockquote = (type: any) => type === 'blockquote';

// Convert element to a list of paragraphs
const canonicalize = (topLevel: Node, at: Path, editor: Editor) => {
  if (!Element.isElement(topLevel)) return;

  if (isHeading(topLevel.type)) {
    Transforms.setNodes(
      editor,
      { type: 'p' },
      { at, match: (e) => Element.isElement(e) && headings.includes(e.type) },
    );
  } else if (isList(topLevel.type)) {
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
  } else if (isBlockquote(topLevel.type)) {
    Transforms.unwrapNodes(editor, { at });
  }
};

// Transform to desired type of node
const convert = (type: any, editor: Editor) => {
  if (!editor.selection) return;

  if (isHeading(type)) {
    Transforms.setNodes(
      editor,
      { type },
      { match: (e) => Element.isElement(e) && e.type === 'p', at: editor.selection },
    );
  } else if (isList(type)) {
    Transforms.setNodes(
      editor,
      { type: 'li' },
      { match: (e) => Element.isElement(e) && e.type === 'p', mode: 'all' },
    );
    Transforms.wrapNodes(editor, Model.ul(), {
      match: (e) => Element.isElement(e) && e.type === 'li',
      mode: 'all',
    });
  } else if (isBlockquote(type)) {
    Transforms.wrapNodes(editor, Model.blockquote(), {
      match: (e) => Element.isElement(e) && e.type === 'p',
    });
  }
};

export const switchType = (editor: Editor, type: any) => {
  const [topLevel, at] = [...Editor.nodes(editor)][1];

  Editor.withoutNormalizing(editor, () => {
    canonicalize(topLevel, at, editor);
    convert(type, editor);
  });
};
