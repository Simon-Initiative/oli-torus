import { Model } from 'data/content/model/elements/factories';
import { ModelElement } from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import * as Immutable from 'immutable';
import { Editor, Element, Path, Transforms } from 'slate';

const spacesRequiredBetween = Immutable.Set<string>([
  'image',
  'youtube',
  'audio',
  'blockquote',
  'code',
  'table',
  'iframe',
]);

export const normalize = (editor: Editor, node: ModelElement | FormattedText, path: Path) => {
  // Ensure that certain blocks types, when found next to each other,
  // get a paragraph inserted in between them

  // For every block that has a next sibling, look to see if this block and the sibling
  // are both block types that need to have whitespace between them.
  const [parent] = Editor.parent(editor, path);
  if (path[path.length - 1] + 1 < parent.children.length) {
    const nextItem = Editor.node(editor, Path.next(path));

    if (nextItem !== undefined) {
      const [nextNode] = nextItem;
      if (Element.isElement(node) && Element.isElement(nextNode)) {
        if (spacesRequiredBetween.has(nextNode.type) && spacesRequiredBetween.has(node.type)) {
          Transforms.insertNodes(editor, Model.p(), { mode: 'highest', at: Path.next(path) });

          return; // Return here necessary to enable multi-pass normalization
        }
      }
    }
  }
};
