import { KeyboardEvent } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Range, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';


const command: Command = {
  execute: (context, editor: ReactEditor) => {
    const quote = ContentModel.create<ContentModel.Blockquote>(
      { type: 'blockquote', children: [{ type: 'p', children: [{ text: '' }] }], id: guid() });
    Transforms.insertNodes(editor, quote);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-quote-right',
  description: 'Quote',
  command,
};

export interface BlockQuoteProps extends EditorProps<ContentModel.Blockquote> {
}

export const BlockQuoteEditor = (props: BlockQuoteProps) => {

  const { attributes, children } = props;
  const style = {
    margin: '30px',
    backgroundColor: '#EEEEEE',
    borderLeft: 'solid 1px blue',
    padding: '5px',
  };

  return (
    <blockquote style={style} className="blockquote" {...attributes}>
      {children}
    </blockquote>
  );
};

