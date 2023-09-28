import { Editor, Element, Path, Transforms } from 'slate';
import { Hyperlink, ModelElement } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import { isEmptyContent } from 'data/content/utils';

const isLink = (node: ModelElement | FormattedText): node is Hyperlink =>
  Element.isElement(node) && node.type === 'a';

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {

  if (isLink(node)) {
    console.info("Normalizing Content: Link",node)
    /* We're going to remove any links that have no content in them at all. */
    if (isEmptyContent(node.children)) {
      /* However, if the cursor is currently inside the node, do not delete it. This handles
         the one case where a user inserts a link on an empty line with the intention of immiediately
         typing some text into it. */
      if (editor.selection) {
        const [start, end] = Editor.edges(editor, editor.selection);
        if (Path.isAncestor(path, start.path) || Path.isAncestor(path, end.path)) {
          console.info("Could not remove empty link: Cursor inside")
          return false;
        }
      }
      console.warn("Normalizing Content: Removing empty link.")
      Transforms.removeNodes(editor, { at: path });
      return true;
    }
  }
  return false;
};
