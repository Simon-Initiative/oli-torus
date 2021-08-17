import { getCommand as imageCommandBuilder } from 'components/editing/commands/ImageCmd';
import { commandDesc as ytCmdDesc } from 'components/editing/commands/YoutubeCmd';
import { commandDesc as webpageCmdDesc } from 'components/editing/commands/WebpageCmd';
import { getCommand as audioCommandBuilder } from 'components/editing/commands/AudioCmd';
import { commandDesc as tableCommandDesc } from 'components/editing/commands/table/TableCmd';
import { ResourceType } from 'data/content/resource';
import { ToolbarItem } from 'components/editing/commands/interfaces';
import { commandDesc as codeCmd } from 'components/editing/commands/BlockcodeCmd';

// Can be extended to provide different insertion toolbar options based on resource type
export function getToolbarForResourceType(
  resourceType: ResourceType,
  onRequestMedia: any,
): ToolbarItem[] {
  return [
    tableCommandDesc,
    codeCmd,
    {
      type: 'GroupDivider',
    },
    imageCommandBuilder(onRequestMedia),
    ytCmdDesc,
    audioCommandBuilder(onRequestMedia),
    webpageCmdDesc,
  ];
}
