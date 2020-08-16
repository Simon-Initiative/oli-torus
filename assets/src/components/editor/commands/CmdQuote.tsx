import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { getHighestTopLevel } from 'components/editor/utils';
import { CommandDesc, Command } from 'components/editor/commands/interfaces';

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const wrapInQuote = () => {
      Transforms.wrapNodes(editor, ContentModel.quote());
    };

    getHighestTopLevel(editor).caseOf({
      just: n => n.type === 'blockquote'
        ? Transforms.unwrapNodes(editor, { match: n => n.type === 'blockquote' })
        : wrapInQuote(),
      nothing: wrapInQuote,
    });
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'format_quote',
  description: 'Quote',
  command,
  active: (editor: ReactEditor) => getHighestTopLevel(editor).caseOf({
    just: n => n.type === 'blockquote',
    nothing: () => false,
  }),
};
