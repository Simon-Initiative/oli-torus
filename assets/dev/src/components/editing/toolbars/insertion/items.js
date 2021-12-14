import { getCommand as audioCommandBuilder } from 'components/editing/commands/AudioCmd';
import { commandDesc as codeCmd } from 'components/editing/commands/BlockcodeCmd';
import { getCommand as imageCommandBuilder } from 'components/editing/commands/ImageCmd';
import { commandDesc as tableCommandDesc } from 'components/editing/commands/table/TableCmd';
import { commandDesc as webpageCmdDesc } from 'components/editing/commands/WebpageCmd';
import { commandDesc as ytCmdDesc } from 'components/editing/commands/YoutubeCmd';
// Can be extended to provide different insertion toolbar options based on resource type
export function getToolbarForContentType(onRequestMedia, type = 'all') {
    if (type === 'small') {
        return [
            codeCmd,
            imageCommandBuilder(onRequestMedia),
            ytCmdDesc,
            audioCommandBuilder(onRequestMedia),
        ];
    }
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
//# sourceMappingURL=items.js.map