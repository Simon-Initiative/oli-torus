import { schema } from 'data/content/model/schema';
import { Marks } from 'data/content/model/text';
import { Editor, Element, Node, Text, } from 'slate';
import { Maybe } from 'tsmonad';
// Native input selection -- not slate
export const cursorAtEndOfInput = (input) => {
    return input.selectionStart === input.selectionEnd && input.selectionStart === input.value.length;
};
export const cursorAtBeginningOfInput = (input) => {
    return input.selectionStart === input.selectionEnd && input.selectionStart === 0;
};
// Returns true if a text node contains the mark string key
export function hasMark(textNode, mark) {
    return Object.keys(textNode).some((k) => k === mark);
}
export function elementsOfType(root, type) {
    return [...Node.elements(root)]
        .map(([element]) => element)
        .filter((elem) => Element.isElement(elem) && elem.type === type);
}
export function elementsAdded(operations, type) {
    return operations
        .filter((operation) => operation.type === 'insert_node' &&
        Element.isElement(operation.node) &&
        operation.node.type === type)
        .map((operation) => operation.node);
}
export function elementsRemoved(operations, type) {
    return operations
        .filter((operation) => operation.type === 'remove_node' &&
        Element.isElement(operation.node) &&
        operation.node.type === type)
        .map((operation) => operation.node);
}
// Returns all the Text nodes in the current selection
export function textNodesInSelection(editor) {
    const selection = editor.selection;
    if (!selection) {
        return [];
    }
    return Node.fragment(editor, selection)
        .map((node) => Array.from(Node.descendants(node)).reduce((acc, [node]) => {
        return Text.isText(node) ? acc.concat(node) : acc;
    }, []))
        .reduce((acc, curr) => acc.concat(curr), []);
}
export function isMarkActive(editor, mark) {
    return marksInPartOfSelection(editor).includes(mark);
}
// Returns a Mark[] that apply to the entire current selection
export function marksInEntireSelection(editor) {
    const marks = {};
    const textNodes = textNodesInSelection(editor);
    textNodes.forEach((text) => {
        Object.keys(text)
            .filter((k) => k in Marks)
            .forEach((mark) => (marks[mark] ? (marks[mark] += 1) : (marks[mark] = 1)));
    });
    return Object.entries(marks)
        .filter(([, v]) => v === textNodes.length)
        .map(([k]) => k);
}
// Returns a Mark[] of all marks that exist in any part of the current selection
export function marksInPartOfSelection(editor) {
    const marks = {};
    textNodesInSelection(editor).forEach((text) => {
        Object.keys(text)
            .filter((k) => k in Marks)
            .forEach((mark) => (marks[mark] = true));
    });
    return Object.keys(marks);
}
export function toSimpleText(node) {
    if (Array.isArray(node))
        return toSimpleTextHelper({ children: node }, '');
    return toSimpleTextHelper(node, '');
}
function toSimpleTextHelper(node, text) {
    if (Text.isText(node))
        return text + node.text;
    return [...node.children].reduce((p, c) => {
        if (Text.isText(c))
            return p + c.text;
        return toSimpleTextHelper(c, p);
    }, text);
}
export const isTopLevel = (editor) => {
    const [...nodes] = Editor.nodes(editor, {
        match: (n) => {
            if (!Element.isElement(n))
                return false;
            const attrs = schema[n.type];
            return attrs && attrs.isTopLevel;
        },
    });
    return nodes.every((node) => node[1].length === 1);
};
export const getHighestTopLevel = (editor) => {
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
export const getNearestBlock = (editor) => {
    const block = Editor.above(editor, {
        match: (n) => Editor.isBlock(editor, n),
    });
    if (block) {
        return Maybe.just(block[0]);
    }
    return Maybe.nothing();
};
export const isActive = (editor, type) => {
    const [match] = Editor.nodes(editor, {
        match: (n) => Element.isElement(n) &&
            (typeof type === 'string' ? n.type === type : type.indexOf(n.type) > -1),
    });
    return !!match;
};
export const isActiveList = (editor) => {
    return isActive(editor, ['ul', 'ol']);
};
//# sourceMappingURL=utils.jsx.map