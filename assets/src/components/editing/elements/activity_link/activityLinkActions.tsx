import React, { useState } from 'react';
import { Transforms, Editor, Element, Location } from 'slate';
import { isActive } from '../../slateUtils';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { ActivityLink } from 'data/content/model/elements/types';
import { CommandContext } from '../commands/interfaces';
import { modalActions } from 'actions/modal';
import { ActivityLinkModal } from './ActivityLinkModal';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function selectPage(commandContext: CommandContext): Promise<string | undefined> {
  return new Promise((resolve, _reject) => {
    display(
      <ActivityLinkModal
        commandContext={commandContext}
        onDone={({ ref }: Partial<ActivityLink>) => {
          dismiss();
          resolve(ref);
        }}
        onCancel={() => dismiss()}
      />,
    );
  });
}

// export const insertActivityLink = createButtonCommandDesc({
//   icon: 'label',
//   description: 'Activity Link',
//   execute: (_context, editor, _params) => {
//     const selection = editor.selection;
//     if (!selection) return;

//     const at = editor.selection as any;
//     Transforms.insertNodes(editor, Model.activity_link(), { at });
//   },
//   precondition: (editor) => !isActive(editor, ['code']),
//   active: (e) => isActive(e, 'activity_link'),
// });
export const insertActivityLink = createButtonCommandDesc({
  icon: 'label',
  description: 'Activity Link',
  execute: (context, editor) =>
    selectPage(context).then((ref) => {
      if (ref) {
        const at = editor.selection as Location;
        Transforms.insertNodes(editor, Model.activity_link(ref), { at });
      }
    }),
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'activity_link'),
});
