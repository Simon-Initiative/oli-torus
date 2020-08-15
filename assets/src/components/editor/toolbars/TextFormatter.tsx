import { ReactEditor } from 'slate-react';
import { Node, Transforms } from 'slate';
import { getNearestBlock } from '../utils';
import { Command, CommandDesc } from '../interfaces';

const parentTextTypes = {
  p: true,
  h1: true,
  h2: true,
  h3: true,
  h4: true,
  h5: true,
  h6: true,
};

const selectedType = (editor: ReactEditor) => getNearestBlock(editor).caseOf({
  just: n => (parentTextTypes as any)[n.type as string] ? n.type as string : 'p',
  nothing: () => 'p',
});

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const nextType = ((selected) => {
      switch (selected) {
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6': return 'p';
        case 'h1': return 'h2';
        case 'p': return 'h1';
      }
    })(selectedType(editor));

    getNearestBlock(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type as string]) {
        const path = ReactEditor.findPath(editor, n);
        Transforms.setNodes(editor, { type: nextType }, { at: path });
      }
    });
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

const icon = (editor: ReactEditor) => {
  const type = selectedType(editor);
  switch (type) {
    case 'h1': return 'title';
    case 'h2': return 'text_fields';
    default: return 'title';
  }
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon,
  description: 'Title',
  command,
  active: (editor: ReactEditor) => selectedType(editor) === 'h1' || selectedType(editor) === 'h2',
};
