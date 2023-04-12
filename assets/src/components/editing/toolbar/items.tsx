import { insertAudio } from 'components/editing/elements/audio/audioActions';
import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { insertImage } from 'components/editing/elements/image/imageActions';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import { toggleList } from 'components/editing/elements/list/listActions';
import {
  additionalFormattingOptions,
  toggleFormat,
} from 'components/editing/elements/marks/toggleMarkActions';
import { toggleParagraph } from 'components/editing/elements/paragraph/paragraphActions';
import { insertTable } from 'components/editing/elements/table/commands/insertTable';
import { insertWebpage } from 'components/editing/elements/webpage/webpageActions';
import { insertYoutube } from 'components/editing/elements/youtube/youtubeActions';
import React from 'react';
import { Editor } from 'slate';

export const formattingDropdownAction = createButtonCommandDesc({
  icon: <i className="fa-solid fa-caret-down"></i>,
  description: 'More',
  execute: (_context, _editor, _action) => {},
  active: (e) => additionalFormattingOptions.some((opt) => opt.active?.(e)),
});

export const toggleTextTypes = [toggleParagraph, toggleHeading, toggleList, toggleBlockquote];

export const activeBlockType = (editor: Editor) =>
  toggleTextTypes.find((type) => type?.active?.(editor)) || toggleTextTypes[0];

export const addItemDropdown: CommandDescription = {
  type: 'CommandDesc',
  icon: () => <i className="fa-solid fa-plus"></i>,
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
  toggleFormat({ icon: <i className="fa-solid fa-bold"></i>, mark: 'strong', description: 'Bold' }),
  toggleFormat({ icon: <i className="fa-solid fa-italic"></i>, mark: 'em', description: 'Italic' }),
  linkCmd,
];
