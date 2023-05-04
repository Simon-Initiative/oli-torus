import React, { ChangeEvent, useCallback } from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import { AudioClipPicker } from '../common/AudioClipPicker';
import { useEditModelCallback } from '../utils';
import { DropdownMenu } from './TableDropdownMenu';
import { cellAttributes } from './table-util';

export const TcEditor = (props: EditorProps<ContentModel.TableConjugation>) => {
  const onEdit = useEditModelCallback(props.model);
  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const onAudioChanged = useCallback(
    (src?: ContentModel.AudioSource) => {
      onEdit({ ...props.model, audioSrc: src?.url, audioType: src?.contenttype });
    },
    [onEdit, props.model],
  );

  const maybeMenu =
    selected && focused ? (
      <DropdownMenu editor={editor} model={props.model} mode="conjugation" />
    ) : null;

  const onEditPronouns = useCallback(
    (event: ChangeEvent<HTMLInputElement>) => {
      onEdit({
        ...props.model,
        pronouns: event.target.value,
      });
    },
    [onEdit, props.model],
  );

  return (
    <td {...props.attributes} {...cellAttributes(props.model)}>
      <div contentEditable={false}>
        <input
          type="text"
          value={props.model.pronouns}
          onChange={onEditPronouns}
          placeholder="Pronouns (optional)"
          className="form-control"
        />
      </div>
      <div contentEditable={false}>
        <AudioClipPicker
          commandContext={props.commandContext}
          clipSrc={props.model.audioSrc}
          onChange={onAudioChanged}
        >
          <label>
            Audio Clip <i>(optional)</i>
          </label>
        </AudioClipPicker>
      </div>
      <div className="form-control tc-content">
        {maybeMenu}
        {props.children}
      </div>
    </td>
  );
};
