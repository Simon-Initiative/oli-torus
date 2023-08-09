import { Editor, Element, Node, NodeEntry, Text, Transforms } from 'slate';
import { normalize as blockNormalize } from 'components/editing/editor/normalizers/block';
import { normalize as forceRootNode } from 'components/editing/editor/normalizers/forceRootNode';
import { normalize as listNormalize } from 'components/editing/editor/normalizers/lists';
import { normalize as rootNormalize } from 'components/editing/editor/normalizers/root';
import { normalize as spacesNormalize } from 'components/editing/editor/normalizers/spaces';
import { normalize as tableNormalize } from 'components/editing/editor/normalizers/tables';
import { Model } from 'data/content/model/elements/factories';
import { AllModelElements } from 'data/content/model/elements/types';

export interface NormalizerContext {
  // Node types normally not allowed in an editor
  whitelist?: string[];
}

const restrictedElements = new Set(['input_ref']);

export interface NormalizerOptions {
  insertParagraphStartEnd: boolean;
  removeRestricted: boolean;
  wrapParagraphs: boolean;
  spacesNormalize: boolean;
  blockNormalize: boolean;
  listNormalize: boolean;
  tableNormalize: boolean;
  conjugationNormalize: boolean;
  forceRootNode?: AllModelElements; // Force us to have a single root node of a specific type
}

const defaultOptions = {
  insertParagraphStartEnd: true,
  removeRestricted: true,
  wrapParagraphs: true,
  spacesNormalize: true,
  blockNormalize: true,
  codeNormalize: true,
  listNormalize: true,
  tableNormalize: true,
  forceRootNode: undefined,
};

export function installNormalizer(
  editor: Editor,
  context: NormalizerContext = {},
  options: Partial<NormalizerOptions> = defaultOptions,
) {
  const { normalizeNode } = editor;

  options = {
    ...defaultOptions,
    ...options,
  };

  editor.normalizeNode = (entry: NodeEntry<Node>) => {
    try {
      const [node, path] = entry;

      if (options.forceRootNode && forceRootNode(editor, node, path, options.forceRootNode)) return;

      if (Editor.isEditor(node)) {
        if (options.insertParagraphStartEnd) {
          return rootNormalize(editor, node, path);
        } else {
          return normalizeNode(entry);
        }
      }

      if (
        options.removeRestricted &&
        Element.isElement(node) &&
        restrictedElements.has(node.type)
      ) {
        if (!context.whitelist?.includes(node.type)) {
          Transforms.removeNodes(editor, { at: path });
          console.warn('Normalizing content: removed restricted element', node.type);
          return;
        }
      }

      const [parent] = Editor.parent(editor, path);

      // Check this node's parent constraints
      if (options.wrapParagraphs && Editor.isEditor(parent)) {
        // Handle text nodes at the top level - they should be paragraphs.
        if (Text.isText(node)) {
          Transforms.wrapNodes(editor, Model.p(), { at: path });
          console.warn('Normalizing content: wrapped top level text node in paragraph');
          return;
        }
      }

      if (options.spacesNormalize && spacesNormalize(editor, node, path)) return;

      // 8/9/2023 - When code elements were set to isVoid=true, these normalizers stopped doing anything
      // if (options.codeNormalize && codeNormalize(editor, node, path)) return;

      if (options.listNormalize && listNormalize(editor, node, path)) return; // Must come before block normalizer
      if (options.blockNormalize && blockNormalize(editor, node, path)) return;

      if (options.tableNormalize && tableNormalize(editor, node, path)) return;
    } catch (e) {
      // istanbul ignore next
      console.error('Normalization Error:', e);
    }
    normalizeNode(entry);
  };
}
