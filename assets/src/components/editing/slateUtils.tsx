import {
  Descendant,
  Editor,
  Element,
  InsertNodeOperation,
  Node,
  NodeEntry,
  Operation,
  RemoveNodeOperation,
  Text,
} from 'slate';
import { ReactEditor } from 'slate-react';
import { Maybe } from 'tsmonad';
import { RichText } from 'components/activities/types';
import { ModelElement } from 'data/content/model/elements/types';
import { schema } from 'data/content/model/schema';
import { Mark } from 'data/content/model/text';

export function elementsOfType<T extends Element>(root: Editor, type: string): T[] {
  return [...Node.elements(root)]
    .map(([element]) => element)
    .filter((elem) => Element.isElement(elem) && elem.type === type) as T[];
}

export function elementsAdded<T extends Element>(operations: Operation[], type: string): T[] {
  return operations
    .filter(
      (operation) =>
        operation.type === 'insert_node' &&
        Element.isElement(operation.node) &&
        operation.node.type === type,
    )
    .map((operation: InsertNodeOperation) => operation.node as T);
}

export function elementsRemoved<T extends Element>(operations: Operation[], type: string): T[] {
  return operations
    .filter(
      (operation) =>
        operation.type === 'remove_node' &&
        Element.isElement(operation.node) &&
        operation.node.type === type,
    )
    .map((operation: RemoveNodeOperation) => operation.node as T);
}

export function isMarkActive(editor: Editor, mark: Mark): boolean {
  const marks = Editor.marks(editor);
  return !!marks && !!marks[mark];
}

// Extracts the text from a hierarchy of nodes
export function toSimpleText(nodes: RichText | Descendant[]): string;
export function toSimpleText(node: Node): string;
export function toSimpleText(node: Node | RichText | Descendant[]): string {
  if (Array.isArray(node)) return toSimpleTextHelper({ children: node } as ModelElement, '');
  return toSimpleTextHelper(node, '');
}

function toSimpleTextHelper(node: Node, text: string): string {
  if (Text.isText(node)) {
    return text + node.text;
  } else if (Array.isArray(node.children)) {
    return [...node.children].reduce((p, c) => {
      if (Text.isText(c)) return p + c.text;
      return toSimpleTextHelper(c, p);
    }, text);
  } else {
    return '';
  }
}

export const isTopLevel = (editor: Editor) => {
  const [...nodes] = Editor.nodes(editor, {
    match: (n) => {
      if (!Element.isElement(n)) return false;
      return schema[n.type]?.isTopLevel || false;
    },
  });
  return nodes.every((node) => node[1].length === 1);
};

export const getHighestTopLevel = (editor: Editor): Maybe<Node> => {
  if (!editor.selection) return Maybe.nothing();

  const selectedNodes = [...Editor.nodes(editor)];
  if (selectedNodes.length < 2) return Maybe.nothing();
  // selectedNodes[0] == Editor, selectedNodes[1] == highestTopLevel
  return Maybe.just(selectedNodes[1][0]);
};

export const safeToDOMNode = (editor: Editor, node: Node): Maybe<HTMLElement> => {
  try {
    return Maybe.just(ReactEditor.toDOMNode(editor, node));
  } catch (_) {
    // This can fail if the editor hasn't been persisted with a newly added node yet,
    // even if the element is "in" the DOM.
    return Maybe.nothing();
  }
};

// For the current selection, walk up through the data model to find the
// immediate block parent.
export const getNearestBlock = (editor: Editor): Maybe<ModelElement> => {
  const block: NodeEntry<ModelElement> | undefined = findNearestBlock(editor);
  if (block) return Maybe.just(block[0]);
  return Maybe.nothing();
};

export const findNearestBlock = (editor: Editor): NodeEntry<ModelElement> | undefined => {
  const block: NodeEntry<ModelElement> | undefined = Editor.above(editor, {
    match: (n) => Element.isElement(n) && Editor.isBlock(editor, n),
  });
  return block;
};

export const isActive = (editor: Editor, type: string | string[]) => {
  const [match] = Editor.nodes(editor, {
    match: (n) =>
      Element.isElement(n) &&
      (typeof type === 'string' ? n.type === type : type.indexOf(n.type as string) > -1),
  });
  return !!match;
};

/**
 * Returns true if all the properties in propMap match properties in node.
 *
 * Examples:
 *   containsProps({a: 5}, {a: 5}) => true
 *   containsProps({a: 5, b: 5}, {a: 5}) => true, extra params in node don't matter
 *   containsProps({a: 5}, {a: 6}) => false, a doesn't equal
 *   containsProps({a: 5}, {a: 5, b: 6}) => false, b is not in node
 */
const containsProps = (node: any, propMap: Record<string, string>): boolean => {
  return Object.keys(propMap).reduce((result, currentKey) => {
    return result && node[currentKey] === propMap[currentKey];
  }, true);
};

/**
 * Returns true if a specific property (or set of properties) are currently active.
 *
 * Example:
 *   Do we currently have an image selected with the given src:
 *     isPropActive(editor, "img", { src: 'http://example.com/image.jpg' })
 *
 *   Do we currently have a list selected with the given style?
 *     isPropActive(editor, ["ul", "ol"], { style: 'disc' })
 *
 */
export const isPropActive = (
  editor: Editor,
  type: string | string[],
  propMap: Record<string, string>,
) => {
  const [match] = Editor.nodes(editor, {
    match: (n) =>
      Element.isElement(n) &&
      (typeof type === 'string' ? n.type === type : type.indexOf(n.type as string) > -1) &&
      containsProps(n, propMap),
  });
  return !!match;
};
