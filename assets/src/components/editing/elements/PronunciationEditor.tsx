import { Model } from '../../../data/content/model/elements/factories';
import { AudioSource, Pronunciation } from '../../../data/content/model/elements/types';
import { CommandContext } from './commands/interfaces';
import { AudioClipPicker } from './common/AudioClipPicker';
import { InlineEditor } from './common/settings/InlineEditor';
import React, { useCallback, useMemo } from 'react';
import { v4 } from 'uuid';

interface Props {
  pronunciation: Pronunciation;
  onEdit: (pronunciation: Pronunciation) => void;
  commandContext: CommandContext;
}

const pronunciationOrDefault = (pronunciation: Pronunciation) =>
  pronunciation || Model.definitionPronunciation();

export const PronunciationEditor: React.FC<Props> = ({ pronunciation, onEdit, commandContext }) => {
  const pronunciationId = useMemo(() => v4(), []); // unique id in case there's more than one editor on the page

  const onAudioSourceChanged = useCallback(
    (src?: AudioSource) => {
      onEdit({
        ...pronunciationOrDefault(pronunciation),
        src: src?.url,
        contenttype: src?.contenttype,
      });
    },
    [onEdit, pronunciation],
  );

  const onPronunciationTextEdit = useCallback(
    (newVal) => {
      onEdit({
        ...pronunciationOrDefault(pronunciation),
        children: newVal,
      });
    },
    [pronunciation, onEdit],
  );

  return (
    <div className="form-group pronunciation-editor">
      <label htmlFor={pronunciationId}>
        Pronunciation <small className="text-muted">Optional</small>
      </label>

      <div className="form-control">
        <InlineEditor
          id={pronunciationId}
          commandContext={commandContext}
          placeholder=""
          content={Array.isArray(pronunciation?.children) ? pronunciation.children : []}
          onEdit={onPronunciationTextEdit}
        />
      </div>

      {pronunciation && (
        <AudioClipPicker
          clipSrc={pronunciation.src}
          commandContext={commandContext}
          onChange={onAudioSourceChanged}
        >
          <label>Pronunciation Audio: </label>
        </AudioClipPicker>
      )}
    </div>
  );
};
