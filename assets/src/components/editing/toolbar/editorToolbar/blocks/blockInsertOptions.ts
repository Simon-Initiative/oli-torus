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
import { insertFormula } from '../../../elements/formula/formulaActions';
import { insertCallout } from '../../../elements/callout/calloutActions';
import { insertVideo } from '../../../elements/video/videoActions';
import { insertDefinition } from '../../../elements/definition/definitionActions';
import { insertFigure } from '../../../elements/figure/figureActions';
import { insertDialog } from '../../../elements/dialog/dialogActions';

export const allBlockInsertActions = (onRequestMedia: any) => [
  insertTable,
  insertImage(onRequestMedia),
  insertYoutube,
  insertCodeblock,
  insertVideo,
  insertAudio(onRequestMedia),
  insertWebpage,
  insertFormula,
  insertCallout,
  insertDefinition,
  insertFigure,
  insertDialog,
];

interface Opts {
  type?: ContentModelMode;
  resourceContext?: ResourceContext;
  onAddItem?: AddCallback;
  editorMap?: ActivityEditorMap;
  index?: number[];
  onRequestMedia?: any;
}
export function blockInsertOptions(opts: Opts): CommandDescription[] {
  const defaultOpts: Partial<Opts> = { type: 'all', onRequestMedia: null };
  const { type, onRequestMedia }: Opts = { ...defaultOpts, ...opts };

  switch (type) {
    case 'inline':
      return [];
    case 'small':
      return [
        insertImage(onRequestMedia),
        ytCmdDesc,
        insertVideo,
        insertCodeblock,
        insertAudio(onRequestMedia),
        insertFormula,
      ];
    case 'all':
      return allBlockInsertActions(onRequestMedia);
    default:
      return allBlockInsertActions(onRequestMedia);
  }
}
