import { normalize as tableNormalize } from 'components/editing/editor/normalizers/tables';
import { normalize as rootNormalize } from 'components/editing/editor/normalizers/root';
import { normalize as blockNormalize } from 'components/editing/editor/normalizers/block';
import { normalize as spacesNormalize } from 'components/editing/editor/normalizers/spaces';
import { normalize as listNormalize } from 'components/editing/editor/normalizers/lists';
import { normalize as codeNormalize } from 'components/editing/editor/normalizers/code';
import { Model } from 'data/content/model/elements/factories';
import { Editor, Element, Node, NodeEntry, Text, Transforms } from 'slate';

export interface NormalizerContext {
  // Node types normally not allowed in an editor
  whitelist?: string[];
}

const restrictedElements = new Set(['input_ref']);

export function installNormalizer(editor: Editor, context: NormalizerContext = {}) {
  const { normalizeNode } = editor;

  editor.normalizeNode = (entry: NodeEntry<Node>) => {
    try {
      const [node, path] = entry;
      if (Editor.isEditor(node)) return rootNormalize(editor, node, path);

      if (Element.isElement(node) && restrictedElements.has(node.type)) {
        if (!context.whitelist?.includes(node.type)) {
          Transforms.removeNodes(editor, { at: path });
          return;
        }
      }

      const [parent] = Editor.parent(editor, path);

      // Check this node's parent constraints
      if (Editor.isEditor(parent)) {
        // Handle text nodes at the top level - they should be paragraphs.
        if (Text.isText(node)) {
          Transforms.wrapNodes(editor, Model.p(), { at: path });
          return;
        }
      }

      spacesNormalize(editor, node, path);
      blockNormalize(editor, node, path);
      codeNormalize(editor, node, path);
      listNormalize(editor, node, path);
      tableNormalize(editor, node, path);
    } catch (e) {
      // tslint:disable-next-line
      console.error(e);
    }
    normalizeNode(entry);
  };
}
