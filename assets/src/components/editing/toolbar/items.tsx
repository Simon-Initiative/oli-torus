import { commandDesc as quoteCmd } from 'components/editing/elements/commands/BlockquoteCmd';
import {
  createButtonCommandDesc,
  createToggleFormatCommand as format,
  switchType,
} from 'components/editing/elements/commands/commands';
import { CommandDesc } from 'components/editing/elements/commands/interfaces';
import { commandDesc as linkCmd } from 'components/editing/elements/commands/LinkCmd';
import { ulCommandDesc as ulCmd } from 'components/editing/elements/commands/ListsCmd';
import { isActive } from 'components/editing/utils';
import { SlateEditor } from 'data/content/model/slate';
import { audioCmdDescBuilder } from 'components/editing/elements/commands/AudioCmd';
import { imgCmdDescBuilder } from 'components/editing/elements/commands/ImageCmd';
import { tableCommandDesc } from 'components/editing/elements/commands/table/TableCmd';
import { webpageCmdDesc } from 'components/editing/elements/commands/WebpageCmd';
import { ytCmdDesc } from 'components/editing/elements/commands/YoutubeCmd';
import { popupCmdDesc } from 'components/editing/elements/commands/PopupCmd';
import {
  codeBlockInsertDesc,
  codeBlockToggleDesc,
} from 'components/editing/elements/commands/BlockcodeCmd';

const paragraphDesc = createButtonCommandDesc({
  icon: 'subject',
  description: 'Paragraph',
  active: (editor) =>
    isActive(editor, 'p') &&
    [headingDesc, ulCmd, quoteCmd, codeBlockToggleDesc].every((desc) => !desc.active?.(editor)),
  execute: (_ctx, editor) => switchType(editor, 'p'),
});

const quoteToggleDesc = createButtonCommandDesc({
  icon: 'format_quote',
  description: 'Quote',
  active: (e) => isActive(e, 'blockquote'),
  execute: (_ctx, editor) => switchType(editor, 'blockquote'),
});

const listDesc = createButtonCommandDesc({
  icon: 'format_list_bulleted',
  description: 'List',
  active: (editor) => isActive(editor, ['ul', 'ol']),
  execute: (_ctx, editor) => switchType(editor, 'ul'),
});

const headingDesc = createButtonCommandDesc({
  icon: 'title',
  description: 'Heading',
  active: (editor) => isActive(editor, ['h1', 'h2']),
  execute: (_ctx, editor) => switchType(editor, 'h2'),
});

const underLineDesc = format({
  icon: 'format_underlined',
  mark: 'underline',
  description: 'Underline',
});

const strikethroughDesc = format({
  icon: 'strikethrough_s',
  mark: 'strikethrough',
  description: 'Strikethrough',
});

const subscriptDesc = format({
  icon: 'subscript',
  mark: 'sub',
  description: 'Subscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

const superscriptDesc = format({
  icon: 'superscript',
  mark: 'sup',
  description: 'Superscript',
  precondition: (editor) => !isActive(editor, ['code']),
});

const inlineCodeDesc = format({
  icon: 'code',
  mark: 'code',
  description: 'Code',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const additionalFormattingOptions = [
  underLineDesc,
  strikethroughDesc,
  inlineCodeDesc,
  subscriptDesc,
  superscriptDesc,
  popupCmdDesc,
];

export const textTypeDescs = [paragraphDesc, headingDesc, listDesc, quoteToggleDesc];

export const formattingDropdownDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'expand_more',
  description: () => 'More',
  command: {
    execute: (_context, _editor, _action) => {},
    precondition: (_editor) => true,
  },
  active: (e) => additionalFormattingOptions.some((opt) => opt.active?.(e)),
};

export const activeBlockType = (editor: SlateEditor) =>
  textTypeDescs.find((type) => type.active?.(editor)) || textTypeDescs[0];

export const textTypeDropdownDesc = (editor: SlateEditor): CommandDesc => {
  const type = activeBlockType(editor);
  return {
    type: 'CommandDesc',
    icon: type.icon,
    description: () => 'Change block from ' + type.description(editor),
    command: {} as any,
    active: (_e) => false,
  };
};

export const addDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'add',
  description: () => 'Add item',
  command: {} as any,
  active: (_e) => false,
};

export const addDescs = (onRequestMedia: any) => [
  tableCommandDesc,
  codeBlockInsertDesc,
  imgCmdDescBuilder(onRequestMedia),
  ytCmdDesc,
  audioCmdDescBuilder(onRequestMedia),
  webpageCmdDesc,
];

export const formatMenuCommands = [
  format({ icon: 'format_bold', mark: 'strong', description: 'Bold' }),
  format({ icon: 'format_italic', mark: 'em', description: 'Italic' }),
  linkCmd,
];
