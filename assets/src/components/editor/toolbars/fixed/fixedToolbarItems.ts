import { commandDesc as imgCmdDesc } from 'components/editor/commands/ImageCmd';
import { commandDesc as ytCmdDesc } from 'components/editor/commands/YoutubeCmd';
import { commandDesc as audioCmdDesc } from 'components/editor/commands/AudioCmd';
import { commandDesc as tableCommandDesc } from 'components/editor/commands/table/TableCmd';
import { ResourceType } from 'data/content/resource';
import { ToolbarItem } from 'components/editor/commands/interfaces';

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
