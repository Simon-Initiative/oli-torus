/**
 * This forces there to be a single root node of the specified type. If it doesn't exist, the defaultValue is inserted.
 * This is useful in sub-editors that should edit one specific type of content, such as the table sub editor in the
 * conjugation editor.
 */

import { Editor, Path, Transforms, Node } from 'slate';
import { AllModelElements, ModelElement } from '../../../../data/content/model/elements/types';
import { SlateEditor } from '../../../../data/content/model/slate';
import { FormattedText } from '../../../../data/content/model/text';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText | SlateEditor,
  path: Path,
  defaultNode: AllModelElements,
) => {
  if (Editor.isEditor(node)) {
    if (node.children.length == 0) {
      Transforms.insertNodes(editor, defaultNode as Node);
      console.warn(`Normalizing content: inserting default node: ${defaultNode.type}.`);
      return true;
    }
    return false;
  }

  const [parent] = Editor.parent(editor, path);
  if (Editor.isEditor(parent)) {
    if ('type' in node && node.type != defaultNode.type) {
      Transforms.removeNodes(editor, { at: path });
      console.warn(
        `Normalizing content: Removing root node of type ${node.type} because it is not a ${defaultNode.type}`,
      );
      return true;
    }
  }
  return false;
};
