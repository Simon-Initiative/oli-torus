import { Model } from 'data/content/model/elements/factories';
import { Editor, Path, Transforms } from 'slate';

export const normalize = (editor: Editor, node: Editor, _path: Path) => {
  // Ensure that we always have a paragraph in the document
  if (node.children.length === 0) {
    Transforms.insertNodes(editor, Model.p(), {
      mode: 'highest',
      at: Editor.end(editor, []),
    });
  }
  return;
};
