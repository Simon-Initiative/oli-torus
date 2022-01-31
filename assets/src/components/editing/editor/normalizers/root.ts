import { Model } from 'data/content/model/elements/factories';
import { Editor, Element, Path, Transforms } from 'slate';

export const normalize = (editor: Editor, node: Editor, _path: Path) => {
  // Ensure that we always have a paragraph as the first and last
  // nodes in the document, otherwise it can be impossible for a
  // user to position their cursor
  const first = node.children[0];
  const last = node.children[node.children.length - 1];
  if (!Element.isElement(first) || first.type !== 'p') {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.start(editor, []),
    });
    return;
  }
  if (!Element.isElement(last) || last.type !== 'p') {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.end(editor, []),
    });
    return;
  }
};
