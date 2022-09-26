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
          console.warn('Normalizing content: removed restricted element', node.type);
          return;
        }
      }

      const [parent] = Editor.parent(editor, path);

      // Check this node's parent constraints
      if (Editor.isEditor(parent)) {
        // Handle text nodes at the top level - they should be paragraphs.
        if (Text.isText(node)) {
          Transforms.wrapNodes(editor, Model.p(), { at: path });
          console.warn('Normalizing content: wrapped top level text node in paragraph');
          return;
        }
      }

      // These normalizers should return true if they made a change. In those cases, we should just return here
      // instead of continuning to the next normalizer so slate can set us up for another round of normalization.
      if (spacesNormalize(editor, node, path)) return;
      if (blockNormalize(editor, node, path)) return;
      if (codeNormalize(editor, node, path)) return;
      if (listNormalize(editor, node, path)) return;
      if (tableNormalize(editor, node, path)) return;
    } catch (e) {
      // tslint:disable-next-line
      console.error('Normalization Error:', e);
    }
    normalizeNode(entry);
  };
}
