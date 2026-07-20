import { Editor } from 'slate';
import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { VlabInputType } from 'components/activities/vlab/schema';
import { InputRef } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';

export const CommandCategoryList = [
  'Formatting',
  'Media',
  'STEM',
  'General',
  'Language',
  'Structure',
  'Other',
];

export type CommandCategories = typeof CommandCategoryList[number];

// For toolbar buttons
export type CommandDescription = {
  type: 'CommandDesc';
  icon: (editor: Editor) => JSX.Element | undefined;
  command: Command;
  category?: CommandCategories;
  description: (editor: Editor) => string;
  // active: is the item in the cursor's selection
  active?: (editor: Editor) => boolean;
  tooltip?: string;
};

export interface LinkablePage {
  id: number;
  slug: string;
  title: string;
  numbering_index?: number | null;
}

export interface CommandContext {
  projectSlug: string;
  // When present (email-mode link picker), the link command/modal source internal
  // course-page links from this list instead of the author-only pages endpoint.
  linkContext?: {
    mode: 'email';
    pages: LinkablePage[];
  };
  resourceSlug?: string;
  editorType?: string;
  inputRefContext?: {
    setInputType: (id: ID, attrs: MultiInputType | VlabInputType) => void;
    inputs: Map<ID, MultiInput>;
    selectedInputRef: InputRef | undefined;
    setSelectedInputRef: (ref: InputRef | undefined) => void;
    isMultiInput: boolean;
    hideInputTypeToolbar?: boolean;
    refsTargeted?: string[] | undefined;
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
