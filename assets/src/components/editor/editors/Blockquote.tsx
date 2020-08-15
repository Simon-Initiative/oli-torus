import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { getHighestTopLevel } from '../utils';


const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const wrapInQuote = () => {
      const quote = ContentModel.create<ContentModel.Blockquote>({
        children: [], type: 'blockquote', id: guid() });
      Transforms.wrapNodes(editor, quote);
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

export interface BlockQuoteProps extends EditorProps<ContentModel.Blockquote> {
}

export const BlockQuoteEditor = (props: BlockQuoteProps) => {

  const { attributes, children } = props;

  return (
    <blockquote className="blockquote" {...attributes}>
      {children}
    </blockquote>
  );
};

