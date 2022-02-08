import { Model } from 'data/content/model/elements/factories';
import { Editor, Element, Path, Transforms, Descendant } from 'slate';

const blockTexts = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p'];
const isBlockText = (e: Descendant) => Element.isElement(e) && blockTexts.includes(e.type);

export const normalize = (editor: Editor, node: Editor, _path: Path) => {
  // Ensure that we always have a paragraph/heading as the first and last
  // nodes in the document, otherwise it can be impossible for a
  // user to position their cursor
  const first = node.children[0];
  const last = node.children[node.children.length - 1];
  if (!isBlockText(first)) {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.start(editor, []),
    });
    return;
  }
  if (!isBlockText(last)) {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.end(editor, []),
    });
    return;
  }
};
