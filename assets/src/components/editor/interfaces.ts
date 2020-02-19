import { ReactEditor } from 'slate-react';

export type CommandDesc = {
  type: 'CommandDesc',
  icon: string,
  command: Command,
  description: string,
};

export type Command = {
  precondition: (editor: ReactEditor) => void,
  execute: (editor: ReactEditor) => void,
};

// Width of padding on right hand side to allow toolbar toggler
// to never obstruct text
export const gutterWidth = 18;

export type GroupDivider = {
  type: 'GroupDivider',
};

export type ToolbarItem = CommandDesc | GroupDivider;
