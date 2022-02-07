import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { InputRef } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { Editor } from 'slate';

// For toolbar buttons
export type CommandDescription = {
  type: 'CommandDesc';
  icon: (editor: Editor) => string;
  command: Command;
  description: (editor: Editor) => string;
  // active: is the item in the cursor's selection
  active?: (editor: Editor) => boolean;
};

export interface CommandContext {
  projectSlug: string;
  inputRefContext?: {
    setInputType: (id: ID, attrs: MultiInputType) => void;
    inputs: Map<ID, MultiInput>;
    selectedInputRef: InputRef | undefined;
    setSelectedInputRef: (ref: InputRef | undefined) => void;
  };
}

export type Command = {
  // precondition: must be satisfied for the command to be enabled
  // (prevents commands from violating model constraints)
  precondition: (editor: Editor) => boolean;
  // execute: run when the command is called (usually to create an element and insert it)
  // eslint-disable-next-line
  execute: (context: CommandContext, editor: Editor, params?: Object) => any;
  // obtainParameters: allow the command to gather additional info before running the command
  // (for example, show a size picker for table insertion)
  // Returns a JSX element that will be inserted in a popover
  obtainParameters?: (
    context: CommandContext,
    editor: Editor,
    onDone: (params: any) => void,
    onCancel: () => void,
  ) => JSX.Element;
};
