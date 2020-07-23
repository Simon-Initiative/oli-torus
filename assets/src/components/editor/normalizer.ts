
import { ReactEditor } from 'slate-react';
import * as Immutable from 'immutable';
import { Node, NodeEntry, Editor as SlateEditor, Transforms, Path } from 'slate';
import { normalize as tableNormalize } from './editors/Table';
import { create, schema, Paragraph, SchemaConfig } from 'data/content/model';
import guid from 'utils/guid';

const spacesRequiredBetween = Immutable.Set<string>(['image', 'youtube', 'audio', 'blockquote', 'code', 'table']);

export function installNormalizer(editor: SlateEditor & ReactEditor) {

  const { normalizeNode } = editor;
  editor.normalizeNode = (entry: NodeEntry<Node>) => {

    if ((editor as any).suspendNormalization) {
      normalizeNode(entry);
      return;
    }

    try {
      const [node, path] = entry;

      // Ensure that we always have a paragraph as the last node in
      // the document, otherwise it can be impossible for a user
      // to position their cursor after the last node
      if (SlateEditor.isEditor(node)) {
        const last = node.children[node.children.length - 1];

        if (last.type !== 'p') {
          Transforms.insertNodes(editor, create<Paragraph>(
            { type: 'p', children: [{ text: '' }], id: guid() }),
            { mode: 'highest', at: SlateEditor.end(editor, []) });
        }
        return; // Return here is necessary to enable multi-pass normalization

      }

      // Check this node's parent constraints
      if (SlateEditor.isBlock(editor, node)) {
        const [parent] = SlateEditor.parent(editor, path);
        if (!SlateEditor.isEditor(parent)) {
          const config : SchemaConfig = (schema as any)[parent.type as string];
          if (!(config.validChildren as any)[node.type as string]) {
            Transforms.removeNodes(editor, { at: path });
            return; // Return here is necessary to enable multi-pass normalization
          }

        }
      }

      // Check the top-level constraints
      if (SlateEditor.isBlock(editor, node) && !(schema as any)[node.type as string].isTopLevel) {
        const [parent] = SlateEditor.parent(editor, path);
        if (SlateEditor.isEditor(parent)) {
          Transforms.removeNodes(editor, { at: path });
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

          if (spacesRequiredBetween.has(nextNode.type as any) &&
            spacesRequiredBetween.has(node.type as any)) {

            Transforms.insertNodes(editor, create<Paragraph>(
              { type: 'p', children: [{ text: '' }], id: guid() }),
              { mode: 'highest', at: Path.next(path) });

            return;  // Return here necessary to enable multi-pass normalization
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
