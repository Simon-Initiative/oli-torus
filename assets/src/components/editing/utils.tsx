import { RichText } from 'components/activities/types';
import { ModelElement } from 'data/content/model/elements/types';
import { schema } from 'data/content/model/schema';
import { Mark, Marks } from 'data/content/model/text';
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
import { Maybe } from 'tsmonad';

// Native input selection -- not slate
export const cursorAtEndOfInput = (input: HTMLInputElement) => {
  return input.selectionStart === input.selectionEnd && input.selectionStart === input.value.length;
};
export const cursorAtBeginningOfInput = (input: HTMLInputElement) => {
  return input.selectionStart === input.selectionEnd && input.selectionStart === 0;
};

// Returns true if a text node contains the mark string key
export function hasMark(textNode: Text, mark: string): boolean {
  return Object.keys(textNode).some((k) => k === mark);
}

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

// Returns all the Text nodes in the current selection
export function textNodesInSelection(editor: Editor) {
  const selection = editor.selection;
  if (!selection) {
    return [];
  }

  return Node.fragment(editor, selection)
    .map((node) =>
      Array.from(Node.descendants(node)).reduce((acc: Text[], [node]) => {
        return Text.isText(node) ? acc.concat(node) : acc;
      }, []),
    )
    .reduce((acc, curr) => acc.concat(curr), []);
}

export function isMarkActive(editor: Editor, mark: Mark): boolean {
  const marks = Editor.marks(editor);
  return marks ? !!marks[mark] : false;
}

// Returns a Mark[] that apply to the entire current selection
export function marksInEntireSelection(editor: Editor) {
  const marks: any = {};
  const textNodes = textNodesInSelection(editor);
  textNodes.forEach((text) => {
    Object.keys(text)
      .filter((k) => k in Marks)
      .forEach((mark) => (marks[mark] ? (marks[mark] += 1) : (marks[mark] = 1)));
  });
  return Object.entries(marks)
    .filter(([, v]) => v === textNodes.length)
    .map(([k]) => k as Mark);
}

// Extracts the text from a hierarchy of nodes
export function toSimpleText(nodes: RichText | Descendant[]): string;
export function toSimpleText(node: Node): string;
export function toSimpleText(node: Node | RichText | Descendant[]): string {
  if (Array.isArray(node)) return toSimpleTextHelper({ children: node } as ModelElement, '');
  return toSimpleTextHelper(node, '');
}

function toSimpleTextHelper(node: Node, text: string): string {
  if (Text.isText(node)) return text + node.text;
  return [...node.children].reduce((p, c) => {
    if (Text.isText(c)) return p + c.text;
    return toSimpleTextHelper(c, p);
  }, text);
}

export const isTopLevel = (editor: Editor) => {
  const [...nodes] = Editor.nodes(editor, {
    match: (n) => {
      if (!Element.isElement(n)) return false;
      const attrs = schema[n.type];
      return attrs && attrs.isTopLevel;
    },
  });
  return nodes.every((node) => node[1].length === 1);
};

export const getHighestTopLevel = (editor: Editor): Maybe<Node> => {
  if (!editor.selection) {
    return Maybe.nothing();
  }
  let [node, path] = Editor.node(editor, editor.selection);

  // eslint-disable-next-line
  while (true) {
    // TopLevel node is selected, only Editor node as parent
    if (path.length === 1) {
      return Maybe.maybe(node);
    }
    // Editor is selected
    if (path.length === 0) {
      return Maybe.nothing();
    }
    const [nextNode, nextPath] = Editor.parent(editor, path);
    path = nextPath;
    node = nextNode;
  }
};

// For the current selection, walk up through the data model to find the
// immediate block parent.
export const getNearestBlock = (editor: Editor): Maybe<ModelElement> => {
  const block: NodeEntry<ModelElement> | undefined = Editor.above(editor, {
    match: (n) => Editor.isBlock(editor, n),
  });
  if (block) {
    return Maybe.just(block[0]);
  }
  return Maybe.nothing();
};

export const isActive = (editor: Editor, type: string | string[]) => {
  const [match] = Editor.nodes(editor, {
    match: (n) =>
      Element.isElement(n) &&
      (typeof type === 'string' ? n.type === type : type.indexOf(n.type as string) > -1),
  });
  return !!match;
};

export const isActiveList = (editor: Editor) => {
  return isActive(editor, ['ul', 'ol']);
};
