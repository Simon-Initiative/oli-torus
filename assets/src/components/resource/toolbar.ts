import { ToolbarItem } from '../editor/interfaces';
export { ToolbarItem } from '../editor/interfaces';
import { commandDesc as imageCommandDesc } from '../editor/editors/Image';
import { olCommandDesc as olCmd, ulCommanDesc as ulCmd } from '../editor/editors/Lists';
import { commandDesc as youtubeCommandDesc } from '../editor/editors/YouTube';
import { commandDesc as quoteCommandDesc } from '../editor/editors/Blockquote';
import { commandDesc as audioCommandDesc } from '../editor/editors/Audio';
import { commandDesc as codeCommandDesc } from '../editor/editors/Code';
import { commandDesc as tableCommandDesc } from '../editor/editors/Table';
import { ResourceType } from 'data/content/resource';

const toolbarItems: ToolbarItem[] = [
  tableCommandDesc,
  {
    type: 'GroupDivider',
  },
  quoteCommandDesc,
  {
    type: 'GroupDivider',
  },
  olCmd,
  ulCmd,
  {
    type: 'GroupDivider',
  },
  imageCommandDesc,
  youtubeCommandDesc,
  audioCommandDesc,
  {
    type: 'GroupDivider',
  },
  codeCommandDesc,
];

export function getToolbarForResourceType(resourceType: ResourceType) : ToolbarItem[] {
  return toolbarItems;
}

