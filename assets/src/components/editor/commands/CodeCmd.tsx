import { ReactEditor } from 'slate-react';
import { Transforms, Editor } from 'slate';
import * as ContentModel from 'data/content/model';
import guid from 'utils/guid';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';
import { getNearestBlock, isActiveList } from 'components/editor/utils';

const isCodeBlock = (editor: ReactEditor) => {
  return getNearestBlock(editor)
    .caseOf({
      just: n => n.type === 'code_line' || n.type === 'code',
      nothing: () => false,
    });
};

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    Editor.withoutNormalizing(editor, () => {
      if (!editor.selection) return;

      const Code = ContentModel.create<ContentModel.Code>(
        {
          type: 'code', language: 'python',
          showNumbers: false,
          startingLineNumber: 1, children: [
            { type: 'code_line', children: [{ text: '' }] }], id: guid(),
        });

      Transforms.insertNodes(editor, Code);

      if (isActiveList(editor)) {
        Transforms.wrapNodes(editor,
          { type: 'li', children: [] },
          { match: n => n.type === 'code' });
      }
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

const description = (editor: ReactEditor) => {
  if (isCodeBlock(editor)) {
    return 'Code-line';
  }
  return 'Code';
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'code',
  description,
  command,
};
