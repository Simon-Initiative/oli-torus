import { toggleUnorderedList, toggleOrderedList } from './../../elements/list/listActions';
import { toggleBlockquote } from './../../elements/blockquote/blockquoteActions';
import { Range, Editor, Transforms } from 'slate';
import { isTopLevel } from 'components/editing/utils';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';

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

export const withMarkdown = (context: CommandContext) => (editor: Editor) => {
  const { insertText } = editor;
  const blockTrigger = ' ';
  const codeTrigger = '`';
  const triggers = [blockTrigger, codeTrigger];

  editor.insertText = (text) => {
    const { selection } = editor;

    const setNodes = (type: 'h1' | 'h2') => {
      Transforms.setNodes(editor, { type }, { match: (n) => Editor.isBlock(editor, n) });
    };

    if (
      isTopLevel(editor) &&
      triggers.indexOf(text) > -1 &&
      selection &&
      Range.isCollapsed(selection)
    ) {
      const { anchor } = selection;
      const block = Editor.above(editor, {
        match: (n) => Editor.isBlock(editor, n),
      });
      const path = block ? block[1] : [];
      const start = Editor.start(editor, path);
      const range = { anchor, focus: start };
      const beforeText = Editor.string(editor, range);
      const type: string | undefined = (SHORTCUTS as any)[beforeText];

      if (type) {
        Transforms.select(editor, range);
        Transforms.delete(editor);

        switch (type) {
          case 'h1':
            return setNodes('h1');
          case 'h2':
            return setNodes('h2');
          case 'ul':
            return toggleUnorderedList.command.execute(context, editor);
          case 'ol':
            return toggleOrderedList.command.execute(context, editor);
          case 'blockquote':
            return toggleBlockquote.command.execute(context, editor);
          case 'code':
            return insertCodeblock.command.execute(context, editor);
        }
      }
    }

    insertText(text);
  };

  return editor;
};
