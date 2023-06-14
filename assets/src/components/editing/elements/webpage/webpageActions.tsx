import * as React from 'react';
import { Transforms } from 'slate';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { modalActions } from 'actions/modal';
import { Model } from 'data/content/model/elements/factories';
import { Webpage } from 'data/content/model/elements/types';
import { WebpageModal } from './WebpageModal';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export type WebpageCreationProps = {
  onChange: (src: string) => void;
  onEdit: (src: string) => void;
};

export function selectWebpage(projectSlug: string): Promise<Webpage | null> {
  return new Promise((resolve, _reject) => {
    const initial = Model.webpage('');

    const onDone = (webpage: Partial<Webpage>) => {
      resolve({
        ...initial,
        ...webpage,
      });
      dismiss();
    };

    const onCancel = () => {
      resolve(null);
      dismiss();
    };

    display(
      <WebpageModal
        onDone={onDone}
        onCancel={onCancel}
        model={initial}
        projectSlug={projectSlug}
      />,
    );
  });
}

export const insertWebpage = createButtonCommandDesc({
  icon: <i className="fa-solid fa-globe"></i>,
  description: 'Webpage',
  execute: (context, editor) => {
    const at = editor.selection;
    if (!at) return;

    selectWebpage(context.projectSlug).then((selectedWebpage: Webpage) => {
      if (selectedWebpage !== null) {
        const src = selectedWebpage.src || '';
        if (!src.startsWith('http://') && !src.startsWith('https://')) {
          selectedWebpage.src = 'https://' + src;
        }

        Transforms.insertNodes(editor, selectedWebpage, { at });
      }
    });
  },
});
