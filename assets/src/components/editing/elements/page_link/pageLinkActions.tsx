import React from 'react';
import { Transforms, Location } from 'slate';
import { isActive } from '../../slateUtils';
import { Model } from 'data/content/model/elements/factories';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { CommandContext } from '../commands/interfaces';
import { modalActions } from 'actions/modal';
import * as Persistence from 'data/persistence/resource';
import { Option, SelectModal } from 'components/modal/SelectModal';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function selectPage(commandContext: CommandContext): Promise<{ idref: number }> {
  return new Promise((resolve, reject) => {
    display(
      <SelectModal
        title="Select a Page"
        description="Select a Page"
        onFetchOptions={() =>
          Persistence.pages(commandContext.projectSlug).then((result) => {
            if (result.type === 'success') {
              return result.pages.map((p) => ({ value: p.id, title: p.title } as Option));
            } else {
              throw result.message;
            }
          })
        }
        onDone={(idref: number) => {
          dismiss();
          resolve({ idref });
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
  icon: <i className="fa-solid fa-square-up-right"></i>,
  description: 'Page Link',
  execute: (context, editor) =>
    selectPage(context).then(({ idref }) => {
      if (idref) {
        const at = editor.selection as Location;
        Transforms.insertNodes(editor, Model.page_link(idref), { at });
      }
    }),
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'page_link'),
});
