import { Range, Editor, Transforms } from 'slate';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd, } from 'components/editing/commands/ListsCmd';
import { commandDesc as codeCmd } from 'components/editing/commands/BlockcodeCmd';
import { commandDesc as quoteCmd } from 'components/editing/commands/BlockquoteCmd';
import { isTopLevel } from 'components/editing/utils';
const SHORTCUTS = {
    '#': 'h1',
    '##': 'h2',
    '*': 'ul',
    '-': 'ul',
    '+': 'ul',
    '1)': 'ol',
    '1.': 'ol',
    '>': 'blockquote',
    '``': 'code',
};
export const withMarkdown = (context) => (editor) => {
    const { insertText } = editor;
    const blockTrigger = ' ';
    const codeTrigger = '`';
    const triggers = [blockTrigger, codeTrigger];
    editor.insertText = (text) => {
        const { selection } = editor;
        const setNodes = (type) => {
            Transforms.setNodes(editor, { type }, { match: (n) => Editor.isBlock(editor, n) });
        };
        if (isTopLevel(editor) &&
            triggers.indexOf(text) > -1 &&
            selection &&
            Range.isCollapsed(selection)) {
            const { anchor } = selection;
            const block = Editor.above(editor, {
                match: (n) => Editor.isBlock(editor, n),
            });
            const path = block ? block[1] : [];
            const start = Editor.start(editor, path);
            const range = { anchor, focus: start };
            const beforeText = Editor.string(editor, range);
            const type = SHORTCUTS[beforeText];
            if (type) {
                Transforms.select(editor, range);
                Transforms.delete(editor);
                switch (type) {
                    case 'h1':
                        return setNodes('h1');
                    case 'h2':
                        return setNodes('h2');
                    case 'ul':
                        return ulCmd.command.execute(context, editor);
                    case 'ol':
                        return olCmd.command.execute(context, editor);
                    case 'blockquote':
                        return quoteCmd.command.execute(context, editor);
                    case 'code':
                        return codeCmd.command.execute(context, editor);
                }
            }
        }
        insertText(text);
    };
    return editor;
};
//# sourceMappingURL=markdown.js.map