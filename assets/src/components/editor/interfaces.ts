import { ReactEditor } from 'slate-react';

export type CommandDesc = {
  type: 'CommandDesc',
  icon: string,
  command: Command,
  description: string,
  active?: (marks: string[]) => boolean;
};

export interface CommandContext {
  projectSlug: string;
}

export type Command = {
  precondition: (editor: ReactEditor) => void,
  execute: (context: CommandContext, editor: ReactEditor, params?: Object) => void,
  obtainParameters?: (
    editor: ReactEditor, onDone: (params: any) => void, onCancel: () => void) => JSX.Element,
};

export type GroupDivider = {
  type: 'GroupDivider',
};

export type ToolbarItem = CommandDesc | GroupDivider;
