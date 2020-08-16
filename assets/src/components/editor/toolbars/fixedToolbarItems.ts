import { ToolbarItem } from '../commands/interfaces';
export { ToolbarItem } from '../commands/interfaces';
import { commandDesc as imgCmdDesc } from 'components/editor/commands/buttons/Image';
import { commandDesc as ytCmdDesc } from 'components/editor/commands/buttons/YouTube';
import { commandDesc as audioCmdDesc } from 'components/editor/commands/buttons/Audio';
import { commandDesc as tableCommandDesc } from 'components/editor/commands/buttons/Table';
import { ResourceType } from 'data/content/resource';

const toolbarItems: ToolbarItem[] = [
  tableCommandDesc,
  {
    type: 'GroupDivider',
  },
  imgCmdDesc,
  ytCmdDesc,
  audioCmdDesc,
];

// Can be extended to provide different fixed toolbar options based on resource type
export function getToolbarForResourceType(resourceType: ResourceType) : ToolbarItem[] {
  return toolbarItems;
}
