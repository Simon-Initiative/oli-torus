import { CommandDesc, Command } from 'components/editing/commands/interfaces';
import { Transforms } from 'slate';
import * as ContentModel from 'data/content/model';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import { useState } from 'react';
import * as Settings from 'components/editing/models/settings/Settings';
import { getQueryVariableFromString } from 'utils/params';
import { CUTE_OTTERS } from '../models/youtube/Editor';

const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

export type YouTubeCreationProps = {
  onChange: (src: string) => void;
  onEdit: (src: string) => void;
};
const YouTubeCreation = (props: YouTubeCreationProps) => {

  const [src, setSrc] = useState('');

  return (
    <div>

      <p className="mb-4">Not sure which video you want to use?
        Visit <a href="https://www.youtube.com" target="_blank">YouTube</a> to search and find it.
      </p>

      <form className="form">
        <label>Enter the YouTube Video ID (or just the entire video URL):</label>
        <input type="text" value={src}
          onChange={(e) => { props.onChange(e.target.value); setSrc(e.target.value); }}
          onKeyPress={e => Settings.onEnterApply(e, () => props.onEdit(src))}
          className="form-control mr-sm-2" />
        <div className="mb-2">
          <small>e.g. https://www.youtube.com/watch?v=<strong>zHIIzcWqsP0</strong></small>
        </div>
      </form>

    </div>
  );
};

export function selectYouTube(): Promise<string | null> {

  return new Promise((resolve, reject) => {

    const selected = { src: null };

    const mediaLibrary =
      <ModalSelection title="Insert YouTube video"
        onInsert={() => {
          dismiss();
          resolve(selected.src ? selected.src : CUTE_OTTERS);
        }}
        onCancel={() => dismiss()}
      >
        <YouTubeCreation
          onEdit={(src: string) => { dismiss(); resolve(src); }}
          onChange={(src: string) => { selected.src = src as any; }} />
      </ModalSelection>;

    display(mediaLibrary);
  });
}

const command: Command = {
  execute: (context, editor) => {

    const at = editor.selection as any;

    selectYouTube()
      .then((selectedSrc) => {
        if (selectedSrc !== null) {

          let src = selectedSrc;
          const hasParams = src.includes('?');

          if (hasParams) {
            const queryString = src.substr(src.indexOf('?') + 1);
            src = getQueryVariableFromString('v', queryString);
          } else if (src.indexOf('/youtu.be/') !== -1) {
            src = src.substr(src.lastIndexOf('/') + 1);
          }

          Transforms.insertNodes(
            editor, ContentModel.youtube(src), { at });
        }
      });
  },
  precondition: (editor) => {
    return true;
  },

};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'play_circle_filled',
  description: () => 'YouTube',
  command,
};
