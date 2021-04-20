import { Node, Editor, Text } from 'slate';
import { ReactEditor } from 'slate-react';
import { Marks, schema, Mark } from 'data/content/model';
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

// Returns all the Text nodes in the current selection
export function textNodesInSelection(editor: ReactEditor) {
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

export function isMarkActive(editor: ReactEditor, mark: Mark): boolean {
  const [match] = Editor.nodes(editor, {
    match: (n) => n[mark] === true,
    universal: true,
  });

  return !!match;
}

// Returns a Mark[] that apply to the entire current selection
export function marksInEntireSelection(editor: ReactEditor) {
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

// Returns a Mark[] of all marks that exist in any part of the current selection
export function marksInPartOfSelection(editor: ReactEditor) {
  const marks: any = {};
  textNodesInSelection(editor).forEach((text) => {
    Object.keys(text)
      .filter((k) => k in Marks)
      .forEach((mark) => (marks[mark] = true));
  });
  return Object.keys(marks);
}

// Extracts the text from a hierarchy of nodes
export function toSimpleText(node: Node): string {
  return toSimpleTextHelper(node, '');
}

function toSimpleTextHelper(node: Node, text: string): string {
  return (node.children as any).reduce((p: string, c: any) => {
    let updatedText = p;
    if (c.text) {
      updatedText += c.text;
    }
    if (c.children) {
      return toSimpleTextHelper(c, updatedText);
    }
    return updatedText;
  }, text);
}

export const isTopLevel = (editor: ReactEditor) => {
  const [...nodes] = Editor.nodes(editor, {
    match: (n) => {
      const attrs = (schema as any)[n.type as any];
      return attrs && attrs.isTopLevel;
    },
  });
  return nodes.every((node) => node[1].length === 1);
};

export const getHighestTopLevel = (editor: ReactEditor): Maybe<Node> => {
  if (!editor.selection) {
    return Maybe.nothing();
  }
  let [node, path] = Editor.node(editor, editor.selection);
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
export const getNearestBlock = (editor: ReactEditor): Maybe<Node> => {
  const block = Editor.above(editor, {
    match: (n) => Editor.isBlock(editor, n),
  });
  if (block) {
    return Maybe.just(block[0]);
  }
  return Maybe.nothing();
};

export const isActive = (editor: ReactEditor, type: string | string[]) => {
  const [match] = Editor.nodes(editor, {
    match: (n) =>
      typeof type === 'string' ? n.type === type : type.indexOf(n.type as string) > -1,
  });

  return !!match;
};

export const isActiveList = (editor: ReactEditor) => {
  return isActive(editor, ['ul', 'ol']);
};
