import { ReactEditor } from 'slate-react';

// For toolbar buttons
export type CommandDesc = {
  type: 'CommandDesc',
  icon: string | ((editor: ReactEditor) => string),
  command: Command,
  description: string,
  // Is the formatting is applied to the current selection?
  active?: (...args: any) => boolean;
};

export interface CommandContext {
  projectSlug: string;
}

export type Command = {
  // The condition that must be satisfied for the button to be enabled
  precondition: (editor: ReactEditor) => boolean,
  // The function to run when the button is pressed
  execute: (context: CommandContext, editor: ReactEditor, params?: Object) => void,
  obtainParameters?: (
    editor: ReactEditor, onDone: (params: any) => void, onCancel: () => void) => JSX.Element,
};

export type GroupDivider = {
  type: 'GroupDivider',
};

export type ToolbarItem = CommandDesc | GroupDivider;
