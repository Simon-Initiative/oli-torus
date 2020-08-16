import { commandDesc as imgCmdDesc } from 'components/editor/commands/CmdImage';
import { commandDesc as ytCmdDesc } from 'components/editor/commands/CmdYouTube';
import { commandDesc as audioCmdDesc } from 'components/editor/commands/CmdAudio';
import { commandDesc as tableCommandDesc } from 'components/editor/commands/CmdTable';
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
