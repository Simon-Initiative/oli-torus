import { normalize as tableNormalize } from 'components/editing/editor/normalizers/tables';
import { p, schema, SchemaConfig } from 'data/content/model';
import * as Immutable from 'immutable';
import { Editor as SlateEditor, Element, Node, NodeEntry, Path, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';

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

export function installNormalizer(
  editor: SlateEditor & ReactEditor,
  context: NormalizerContext = {},
) {
  const { normalizeNode } = editor;

  editor.normalizeNode = (entry: NodeEntry<Node>) => {
    try {
      const [node, path] = entry;

      if (Element.isElement(node) && restrictedElements.has(node.type as string)) {
        if (!context?.whitelist?.includes(node.type as string)) {
          Transforms.removeNodes(editor, { at: path });
          return;
        }
      }

      // Ensure that we always have a paragraph as the last node in
      // the document, otherwise it can be impossible for a user
      // to position their cursor after the last node
      if (SlateEditor.isEditor(node)) {
        const last = node.children[node.children.length - 1];

        if (last.type !== 'p') {
          Transforms.insertNodes(editor, p(), { mode: 'highest', at: SlateEditor.end(editor, []) });
        }
        return; // Return here is necessary to enable multi-pass normalization
      }

      // Check this node's parent constraints
      if (SlateEditor.isBlock(editor, node)) {
        const [parent, parentPath] = SlateEditor.parent(editor, path);
        if (!SlateEditor.isEditor(parent)) {
          const config: SchemaConfig = (schema as any)[parent.type as string];
          if (Element.isElement(node) && !(config.validChildren as any)[node.type as string]) {
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
      if (SlateEditor.isBlock(editor, node) && !(schema as any)[node.type as string].isTopLevel) {
        const [parent] = SlateEditor.parent(editor, path);
        if (SlateEditor.isEditor(parent)) {
          Transforms.unwrapNodes(editor, { at: path });
          return; // Return here is necessary to enable multi-pass normalization
        }
      }

      // Ensure that certain blocks types, when found next to each other,
      // get a paragraph inserted in between them

      const [parent] = SlateEditor.parent(editor, path);

      // For every block that has a next sibling, look to see if this block and the sibling
      // are both block types that need to have whitespace between them.
      if (path[path.length - 1] + 1 < parent.children.length) {
        const nextItem = SlateEditor.node(editor, Path.next(path));

        if (nextItem !== undefined) {
          const [nextNode] = nextItem;

          if (
            spacesRequiredBetween.has(nextNode.type as any) &&
            spacesRequiredBetween.has(node.type as any)
          ) {
            Transforms.insertNodes(editor, p(), { mode: 'highest', at: Path.next(path) });

            return; // Return here necessary to enable multi-pass normalization
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
