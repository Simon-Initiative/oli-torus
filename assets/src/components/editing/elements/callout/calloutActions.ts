import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Transforms } from 'slate';
import { Model } from '../../../../data/content/model/elements/factories';

export const insertCallout = createButtonCommandDesc({
  icon: 'web_asset',
  description: 'Callout',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.callout(), { at, select: true });
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
