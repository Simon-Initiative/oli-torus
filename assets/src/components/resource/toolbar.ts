import { ToolbarItem } from '../editor/interfaces';
export { ToolbarItem } from '../editor/interfaces';
import { commandDesc as imageCommandDesc } from '../editor/editors/Image';
import { commandDesc as youtubeCommandDesc } from '../editor/editors/YouTube';
import { commandDesc as audioCommandDesc } from '../editor/editors/Audio';
import { commandDesc as tableCommandDesc } from '../editor/editors/Table';
import { ResourceType } from 'data/content/resource';

const toolbarItems: ToolbarItem[] = [
  tableCommandDesc,
  {
    type: 'GroupDivider',
  },
  imageCommandDesc,
  youtubeCommandDesc,
  audioCommandDesc,
];

export function getToolbarForResourceType(resourceType: ResourceType) : ToolbarItem[] {
  return toolbarItems;
}

