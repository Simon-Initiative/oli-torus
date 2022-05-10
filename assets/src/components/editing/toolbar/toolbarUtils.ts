import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditorMap } from 'data/content/editors';
import { ResourceContext } from 'data/content/resource';
import { insertAudio } from 'components/editing/elements/audio/audioActions';
import { insertImage } from 'components/editing/elements/image/imageActions';
import { ytCmdDesc } from 'components/editing/elements/youtube/YoutubeElement';
import { ContentModelMode } from 'data/content/model/elements/types';
import { insertTable } from 'components/editing/elements/table/commands/insertTable';
import { insertWebpage } from 'components/editing/elements/webpage/webpageActions';
import { insertYoutube } from 'components/editing/elements/youtube/youtubeActions';
import { Editor } from 'slate';
import { toggleTextTypes } from 'components/editing/toolbar/editorToolbar/Block';

export const addItemActions = (onRequestMedia: any) => [
  insertTable,
  insertCodeblock,
  insertImage(onRequestMedia),
  insertYoutube,
  insertAudio(onRequestMedia),
  insertWebpage,
];

interface Opts {
  type?: ContentModelMode;
  resourceContext?: ResourceContext;
  onAddItem?: AddCallback;
  editorMap?: ActivityEditorMap;
  index?: number[];
  onRequestMedia?: any;
}
export function getToolbarForContentType(opts: Opts): CommandDescription[] {
  const defaultOpts: Partial<Opts> = { type: 'all', onRequestMedia: null };
  const { type, resourceContext, onAddItem, editorMap, index, onRequestMedia }: Opts = {
    ...defaultOpts,
    ...opts,
  };

  if (type === 'small') {
    return [insertCodeblock, insertImage(onRequestMedia), ytCmdDesc, insertAudio(onRequestMedia)];
  }

  if (type === 'inline') {
    return [];
  }

  if (!resourceContext || !onAddItem || !editorMap || !index) return addItemActions(onRequestMedia);

  return addItemActions(onRequestMedia);
}

export const activeBlockType = (editor: Editor) =>
  toggleTextTypes.find((type) => type?.active?.(editor)) || toggleTextTypes[0];
