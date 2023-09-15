import { Editor } from 'slate';
import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { InputRef } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';

export type CommandCategories =
  | 'Media'
  | 'Language'
  | 'STEM'
  | 'General'
  | 'Formatting'
  | 'Structure'
  | 'Other';

// Media:
// insertImage
// insertYoutube
// insertVideo
// insertAudio
// insertWebpage

// Language:
// insertDefinition
// insertDialog
// insertConjugation

// STEM:
// insertFormula
// insertCodeblock
// insertFigure

// General:
// insertTable
// insertCallout
// insertPageLink
// insertDescriptionListCommand

// ---- inline:

// Formatting:
// underLineDesc,
// strikethroughDesc,
// deemphasisDesc,
// subscriptDesc,
// doublesubscriptDesc,
// superscriptDesc,

// Language:
// termDesc,
// citationCmdDesc,
// insertForeign,

// Media:
//insertImageInline,
//insertPopup,

// STEM:
//insertInlineFormula,
// insertInlineCodeblock,

// General:
// Link
//insertInlineCallout,
//insertCommandButton,

// For toolbar buttons
export type CommandDescription = {
  type: 'CommandDesc';
  icon: (editor: Editor) => JSX.Element | undefined;
  command: Command;
  category?: CommandCategories;
  description: (editor: Editor) => string;
  // active: is the item in the cursor's selection
  active?: (editor: Editor) => boolean;
};

export interface CommandContext {
  projectSlug: string;
  resourceSlug?: string;
  editorType?: string;
  inputRefContext?: {
    setInputType: (id: ID, attrs: MultiInputType) => void;
    inputs: Map<ID, MultiInput>;
    selectedInputRef: InputRef | undefined;
    setSelectedInputRef: (ref: InputRef | undefined) => void;
    isMultiInput: boolean;
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
