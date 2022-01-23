import { normalize as tableNormalize } from 'components/editing/editor/normalizers/tables';
import { li, p } from 'data/content/model/elements/factories';
import { schema } from 'data/content/model/schema';
import * as Immutable from 'immutable';
import { Editor, Element, Node, NodeEntry, Path, Text, Transforms } from 'slate';
import guid from 'utils/guid';

export interface NormalizerContext {
  // Node types normally not allowed in an editor
  whitelist?: string[];
}

const restrictedElements = new Set(['input_ref']);

const spacesRequiredBetween = Immutable.Set<string>([
  'image',
  'youtube',
  'audio',
  'blockquote',
  'code',
  'table',
  'iframe',
]);

export function installNormalizer(editor: Editor, context: NormalizerContext = {}) {
  const { normalizeNode } = editor;

  editor.normalizeNode = (entry: NodeEntry<Node>) => {
    try {
      const [node, path] = entry;

      if (Element.isElement(node) && restrictedElements.has(node.type)) {
        if (!context.whitelist?.includes(node.type)) {
          Transforms.removeNodes(editor, { at: path });
          return;
        }
      }

      // Ensure that we always have a paragraph as the last node in
      // the document, otherwise it can be impossible for a user
      // to position their cursor after the last node
      if (Editor.isEditor(node)) {
        const last = node.children[node.children.length - 1];

        if (!Element.isElement(last) || last.type !== 'p') {
          Transforms.insertNodes(editor, p(), { mode: 'highest', at: Editor.end(editor, []) });
        }
        return; // Return here is necessary to enable multi-pass normalization
      }

      const [parent, parentPath] = Editor.parent(editor, path);

      // Check this node's parent constraints
      if (Editor.isEditor(parent)) {
        // Handle text nodes at the top level - they should be paragraphs.
        if (Text.isText(node)) {
          Transforms.wrapNodes(editor, p(), { at: path });
          return;
        }
      } else {
        const config = schema[parent.type];

        if (Element.isElement(parent)) {
          // lists
          if (['ol', 'ul'].includes(parent.type)) {
            if (Text.isText(node)) {
              console.log('is text, wrapping');
              Transforms.wrapNodes(editor, li(), { at: path });
              return;
            }
            if (Element.isElement(node) && !config.validChildren[node.type]) {
              Transforms.setNodes(editor, { type: 'li' }, { at: path });
              return;
            }
          }

          // code
          if (parent.type === 'code') {
            if (Text.isText(node)) {
              Transforms.wrapNodes(
                editor,
                { type: 'code_line', id: guid(), children: [] },
                { at: path },
              );
              return;
            }
            if (Element.isElement(node) && !config.validChildren[node.type]) {
              Transforms.setNodes(editor, { type: 'code_line' }, { at: path });
              return;
            }
          }
        }

        // As a fallback, if we can't reconcile the content, just delete it.
        if (Editor.isBlock(editor, node)) {
          if (Element.isElement(node) && !config.validChildren[node.type]) {
            // Special case for code blocks -- they have two wrappers (code, code_line),
            // so deletion removes the inner block and causes validation errors
            if (node.type === 'p' && parent.type === 'code') {
              Transforms.removeNodes(editor, { at: parentPath });
              return;
            }

            Transforms.removeNodes(editor, { at: path });
            return; // Return here is necessary to enable multi-pass normalization
          }
        }
      }

      // Check the top-level constraints
      if (Editor.isBlock(editor, node) && !schema[node.type].isTopLevel) {
        if (Editor.isEditor(parent)) {
          Transforms.unwrapNodes(editor, { at: path });
          return; // Return here is necessary to enable multi-pass normalization
        }
      }

      // Ensure that certain blocks types, when found next to each other,
      // get a paragraph inserted in between them

      // For every block that has a next sibling, look to see if this block and the sibling
      // are both block types that need to have whitespace between them.
      if (path[path.length - 1] + 1 < parent.children.length) {
        const nextItem = Editor.node(editor, Path.next(path));

        if (nextItem !== undefined) {
          const [nextNode] = nextItem;
          if (Element.isElement(node) && Element.isElement(nextNode)) {
            if (spacesRequiredBetween.has(nextNode.type) && spacesRequiredBetween.has(node.type)) {
              Transforms.insertNodes(editor, p(), { mode: 'highest', at: Path.next(path) });

              return; // Return here necessary to enable multi-pass normalization
            }
          }
        }
      }

      // Run any element specific normalizers
      tableNormalize(editor, node, path);
    } catch (e) {
      // tslint:disable-next-line
      console.error(e);
    }
    normalizeNode(entry);
  };
}
