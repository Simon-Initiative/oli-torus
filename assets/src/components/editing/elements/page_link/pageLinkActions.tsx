import React from 'react';
import { Transforms, Location } from 'slate';
import { isActive } from '../../slateUtils';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { CommandContext } from '../commands/interfaces';
import { modalActions } from 'actions/modal';
import { PageLinkModal } from './PageLinkModal';
const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function selectPage(
  commandContext: CommandContext,
): Promise<{ title: string; ref: string }> {
  return new Promise((resolve, reject) => {
    display(
      <PageLinkModal
        commandContext={commandContext}
        onDone={({ title, ref }: { title: string; ref: string }) => {
          dismiss();
          resolve({ title, ref });
        }}
        onCancel={() => {
          dismiss();
          reject();
        }}
      />,
    );
  });
}

export const insertPageLink = createButtonCommandDesc({
  icon: 'label',
  description: 'Page Link',
  execute: (context, editor) =>
    selectPage(context).then(({ title, ref }) => {
      if (ref) {
        const at = editor.selection as Location;
        Transforms.insertNodes(editor, Model.page_link(title, ref), { at });
      }
    }),
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'page_link'),
});
