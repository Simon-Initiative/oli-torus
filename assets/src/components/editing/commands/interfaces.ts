import { ReactEditor } from 'slate-react';

// For toolbar buttons
export type CommandDesc = {
  type: 'CommandDesc',
  icon: (editor: ReactEditor) => string,
  command: Command,
  description: (editor: ReactEditor) => string,
  // active: is the item in the cursor's selection
  active?: (editor: ReactEditor) => boolean;
};

export interface CommandContext {
  projectSlug: string;
}

export type Command = {
  // precondition: must be satisfied for the command to be enabled
  // (prevents commands from violating model constraints)
  precondition: (editor: ReactEditor) => boolean,
  // execute: run when the command is called (usually to create an element and insert it)
  // eslint-disable-next-line
  execute: (context: CommandContext, editor: ReactEditor, params?: Object) => void,
  // obtainParameters: allow the command to gather additional info before running the command
  // (for example, show a size picker for table insertion)
  // Returns a JSX element that will be inserted in a popover
  obtainParameters?: (
    context: CommandContext,
    editor: ReactEditor,
    onDone: (params: any) => void,
    onCancel: () => void,
  ) => JSX.Element,
};

export type GroupDivider = {
  type: 'GroupDivider',
};

export type ToolbarItem = CommandDesc | GroupDivider;
