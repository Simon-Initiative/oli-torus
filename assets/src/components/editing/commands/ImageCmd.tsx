import React from 'react';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { MIMETYPE_FILTERS, SELECTION_TYPES } from 'components/media/manager/MediaManager';
import ModalSelection, { sizes } from 'components/modal/ModalSelection';
import { modalActions } from 'actions/modal';
import { MediaItem } from 'types/media';
import { Command, CommandDesc } from 'components/editing/commands/interfaces';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { Maybe } from 'tsmonad';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export function selectImage(
  projectSlug: string,
  selectedUrl?: string,
): Promise<string | undefined> {
  return new Promise((resolve, reject) => {
    let selectedUrl: string | undefined = undefined;

    const mediaLibrary = (
      <ModalSelection
        title="Select Image"
        size={sizes.extraLarge}
        onInsert={() => {
          dismiss();
          resolve(selectedUrl);
        }}
        onCancel={() => dismiss()}
        disableInsert={true}
        okLabel="Select"
      >
        <UrlOrUpload
          onUrlChange={(url: string) => (selectedUrl = url)}
          onMediaSelectionChange={(mediaOrUrl: MediaItem[]) => (selectedUrl = mediaOrUrl[0]?.url)}
          projectSlug={projectSlug}
          // eslint-disable-next-line
          onEdit={() => { }}
          mimeFilter={MIMETYPE_FILTERS.IMAGE}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={selectedUrl ? [selectedUrl] : []}
        />
      </ModalSelection>
    );

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor) => {
    const at = editor.selection as any;
    selectImage(context.projectSlug).then((img) =>
      Maybe.maybe(img).caseOf({
        just: (img: string) => Transforms.insertNodes(editor, ContentModel.image(img), { at }),
        // eslint-disable-next-line
        nothing: () => { },
      }),
    );
  },
  precondition: (editor) => {
    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'image',
  description: () => 'Image',
  command,
};
