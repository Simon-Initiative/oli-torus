import * as Immutable from 'immutable';
import { Editor, Element, Path, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { ModelElement } from 'data/content/model/elements/types';
import { ModelTypes } from 'data/content/model/schema';
import { FormattedText } from 'data/content/model/text';

export const spacesRequiredBetween = Immutable.Set<ModelTypes>([
  'img',
  'youtube',
  'audio',
  'blockquote',
  'code',
  'table',
  'iframe',
  'definition',
  'figure',
  'callout',
  'dialog',
]);

export const normalize = (
  editor: Editor,
  node: ModelElement | FormattedText,
  path: Path,
): boolean => {
  // Ensure that certain blocks types, when found next to each other,
  // get a paragraph inserted in between them

  // For every block that has a next sibling, look to see if this block and the sibling
  // are both block types that need to have whitespace between them.
  const [parent] = Editor.parent(editor, path);
  if (path[path.length - 1] + 1 < parent.children.length) {
    const nextItem = Editor.node(editor, Path.next(path));

    // istanbul ignore else
    if (nextItem !== undefined) {
      const [nextNode] = nextItem;
      if (Element.isElement(node) && Element.isElement(nextNode)) {
        if (spacesRequiredBetween.has(nextNode.type) && spacesRequiredBetween.has(node.type)) {
          Transforms.insertNodes(editor, Model.p(), { mode: 'highest', at: Path.next(path) });
          console.warn(
            'Normalizing content: inserting spaces between nodes.',
            node.type,
            nextNode.type,
          );
          return true; // Return here necessary to enable multi-pass normalization
        }
      }
    }
  }
  return false;
};
