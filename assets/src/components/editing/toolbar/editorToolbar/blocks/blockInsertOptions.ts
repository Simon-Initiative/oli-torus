import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { insertAudio } from 'components/editing/elements/audio/audioActions';
import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { insertImage } from 'components/editing/elements/image/imageActions';
import { insertTable } from 'components/editing/elements/table/commands/insertTable';
import { insertWebpage } from 'components/editing/elements/webpage/webpageActions';
import { ytCmdDesc } from 'components/editing/elements/youtube/YoutubeElement';
import { insertYoutube } from 'components/editing/elements/youtube/youtubeActions';
import { ActivityEditorMap } from 'data/content/editors';
import { ContentModelMode } from 'data/content/model/elements/types';
import { ResourceContext } from 'data/content/resource';
import { insertCallout } from '../../../elements/callout/calloutActions';
import { insertConjugation } from '../../../elements/conjugation/conjugationActions';
import { insertDefinition } from '../../../elements/definition/definitionActions';
import { insertDescriptionListCommand } from '../../../elements/description/description-list-actions';
import { insertDialog } from '../../../elements/dialog/dialogActions';
import { insertFigure } from '../../../elements/figure/figureActions';
import { insertFormula } from '../../../elements/formula/formulaActions';
import { insertPageLink } from '../../../elements/page_link/pageLinkActions';
import { insertVideo } from '../../../elements/video/videoActions';

export const extendedBlockInsertActions = (onRequestMedia: any) => [
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
  insertConjugation,
  insertDescriptionListCommand,
];

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
  insertPageLink,
  insertConjugation,
  insertDescriptionListCommand,
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
    case 'limited':
      return [
        insertImage(onRequestMedia),
        ytCmdDesc,
        insertVideo,
        insertCodeblock,
        insertAudio(onRequestMedia),
        insertFormula,
      ];
    case 'extended':
      return extendedBlockInsertActions(onRequestMedia);
    case 'all':
    default:
      return allBlockInsertActions(onRequestMedia);
  }
}
