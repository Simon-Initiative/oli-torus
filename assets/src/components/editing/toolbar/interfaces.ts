import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { InputRef } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { Editor } from 'slate';

export type ToolbarItem = ToolbarButtonDesc | GroupDivider;

export interface ToolbarButtonDesc {
  type: 'ToolbarButtonDesc';
  renderMode: 'Simple' | 'Dropdown';

  icon: (editor: Editor) => string;
  command: ButtonCommand;
  description: (editor: Editor) => string;
  // active: is the item in the cursor's selection
  active?: (editor: Editor) => boolean;
}

export interface GroupDivider {
  type: 'GroupDivider';
}

export interface ButtonContext {
  projectSlug: string;
  inputRefContext?: {
    setInputType: (id: ID, attrs: MultiInputType) => void;
    inputs: Map<ID, MultiInput>;
    selectedInputRef: InputRef | undefined;
    setSelectedInputRef: (ref: InputRef | undefined) => void;
  };
}

export interface ButtonCommand {
  // precondition: must be satisfied for the command to be enabled
  // (prevents commands from violating model constraints)
  precondition: (editor: Editor) => boolean;
  // execute: run when the command is called (usually to create an element and insert it)
  execute: (context: ButtonContext, editor: Editor, params?: Record<string, any>) => void;
  // obtainParameters: allow the command to gather additional info before running the command
  // (for example, show a size picker for table insertion)
  // Returns a JSX element that will be inserted in a popover
  obtainParameters?: (
    context: ButtonContext,
    editor: Editor,
    onDone: (params: any) => void,
    onCancel: () => void,
  ) => JSX.Element;
}
