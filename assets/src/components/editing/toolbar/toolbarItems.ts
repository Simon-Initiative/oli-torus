import { getCommand as audioBuilder } from 'components/editing/commands/AudioCmd';
import { commandDesc as blockCode } from 'components/editing/commands/BlockcodeCmd';
import { getCommand as imageBuilder } from 'components/editing/commands/ImageCmd';
import { commandDesc as table } from 'components/editing/commands/table/TableCmd';
import { commandDesc as webpage } from 'components/editing/commands/WebpageCmd';
import { commandDesc as youtube } from 'components/editing/commands/YoutubeCmd';

import { commandDesc as blockquote } from 'components/editing/commands/BlockquoteCmd';
import { formatButtonDesc as format } from 'components/editing/toolbar/commands';
import { commandDesc as link } from 'components/editing/commands/LinkCmd';
import {
  olCommandDesc as orderedList,
  ulCommandDesc as unorderedList,
} from 'components/editing/commands/ListsCmd';
import { commandDesc as popup } from 'components/editing/commands/PopupCmd';
import { commandDesc as title } from 'components/editing/commands/TitleCmd';
import { isActive } from 'components/editing/utils';
import { GroupDivider, ToolbarItem } from 'components/editing/toolbar/interfaces';

const DIVIDER: GroupDivider = {
  type: 'GroupDivider',
};

const bold = format({ icon: () => 'format_bold', mark: 'strong', description: () => 'Bold (⌘B)' });
const italic = format({
  icon: () => 'format_italic',
  mark: 'em',
  description: () => 'Italic (⌘I)',
});
const code = format({
  icon: () => 'code',
  mark: 'code',
  description: () => 'Code (⌘;)',
  precondition: (editor) => !isActive(editor, ['code']),
});

export const formattingItems: ToolbarItem[] = [
  bold,
  italic,
  link,
  code,
  popup,

  DIVIDER,

  orderedList,
  unorderedList,

  DIVIDER,

  title,
  blockquote,
];

const smallInsertionItems = (onRequestMedia: any) => [
  blockCode,
  imageBuilder(onRequestMedia),
  youtube,
  audioBuilder(onRequestMedia),
];

const allInsertionItems = (onRequestMedia: any) => [
  table,
  blockCode,

  DIVIDER,

  imageBuilder(onRequestMedia),
  youtube,
  audioBuilder(onRequestMedia),
  webpage,
];

type ToolbarContentType = 'all' | 'small';
// Can be extended to provide different insertion toolbar options based on resource type
export function getToolbarForContentType(
  onRequestMedia: any,
  type = 'all' as ToolbarContentType,
): ToolbarItem[] {
  if (type === 'small') return smallInsertionItems(onRequestMedia);
  return allInsertionItems(onRequestMedia);
}
