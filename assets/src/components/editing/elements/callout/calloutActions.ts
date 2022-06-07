import { toggleCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { toggleUnorderedList } from 'components/editing/elements/list/listActions';
import { isActive } from 'components/editing/slateUtils';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';

export const insertCallout = createButtonCommandDesc({
  icon: 'web_asset',
  description: 'Callout',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.callout(), { at });
  },
});

export const insertInlineCallout = createButtonCommandDesc({
  icon: 'web_asset',
  description: 'Callout',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.calloutInline(), { at, select: true });
  },
});
