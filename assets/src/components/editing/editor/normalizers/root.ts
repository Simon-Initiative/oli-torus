import { Descendant, Editor, Element, Path, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';

const blockTexts = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p'];
const isBlockText = (e: Descendant) => Element.isElement(e) && blockTexts.includes(e.type);

export const normalize = (editor: Editor, node: Editor, _path: Path) => {
  // Ensure that we always have a paragraph/heading as the first and last
  // nodes in the document, otherwise it can be impossible for a
  // user to position their cursor
  const first = node.children[0];
  const last = node.children[node.children.length - 1];
  if (!isBlockText(first)) {
    // Using a hard-coded path here instead of Editor.start(editor, []) to fix
    // https://github.com/Simon-Initiative/oli-torus/issues/3082
    // Editor.start(editor, []) was returning [0,0] which corresponded to the first
    // text node in the first element, even if it was a void node.
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: [0],
    });
    console.warn('Normalizing content: Inserted paragraph at start of document');
    return;
  }
  if (!isBlockText(last)) {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.end(editor, []),
    });
    console.warn('Normalizing content: Inserted paragraph at end of document');
    return;
  }
};
