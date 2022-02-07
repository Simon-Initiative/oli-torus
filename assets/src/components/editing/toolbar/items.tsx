import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { insertYoutube } from 'components/editing/elements/youtube/youtubeActions';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { toggleList } from 'components/editing/elements/list/listActions';
import { Editor } from 'slate';
import {
  additionalFormattingOptions,
  toggleFormat,
} from 'components/editing/elements/marks/toggleMarkActions';
import { insertWebpage } from 'components/editing/elements/webpage/webpageActions';
import { insertTable } from 'components/editing/elements/table/commands/insertTable';
import { insertImage } from 'components/editing/elements/image/imageActions';
import { insertAudio } from 'components/editing/elements/audio/audioActions';
import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { toggleParagraph } from 'components/editing/elements/paragraph/paragraphActions';

export const formattingDropdownAction = createButtonCommandDesc({
  icon: 'expand_more',
  description: 'More',
  execute: (_context, _editor, _action) => {},
  active: (e) => additionalFormattingOptions.some((opt) => opt.active?.(e)),
});

export const toggleTextTypes = [toggleParagraph, toggleHeading, toggleList, toggleBlockquote];

export const activeBlockType = (editor: Editor) =>
  toggleTextTypes.find((type) => type?.active?.(editor)) || toggleTextTypes[0];

export const addItemDropdown: CommandDescription = {
  type: 'CommandDesc',
  icon: () => 'add',
  description: () => 'Add item',
  command: {} as any,
  active: (_e) => false,
};

export const addItemActions = (onRequestMedia: any) => [
  insertTable,
  insertCodeblock,
  insertImage(onRequestMedia),
  insertYoutube,
  insertAudio(onRequestMedia),
  insertWebpage,
];

export const formatMenuCommands = [
  toggleFormat({ icon: 'format_bold', mark: 'strong', description: 'Bold' }),
  toggleFormat({ icon: 'format_italic', mark: 'em', description: 'Italic' }),
  linkCmd,
];
