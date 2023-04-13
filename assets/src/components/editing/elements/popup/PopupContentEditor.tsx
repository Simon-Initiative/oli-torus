import React, { useCallback } from 'react';
import { RichText } from 'components/activities/types';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import { OverlayTriggerType } from 'react-bootstrap/esm/OverlayTrigger';

import { InlineAudioClipPicker } from '../common/InlineAudioClipPicker';

interface Props {
  onDone: (changes: Partial<ContentModel.Popup>) => void;
  model: ContentModel.Popup;
  commandContext: CommandContext;
}
export const PopupContentEditor = (props: Props) => {
  const [content, setContent] = React.useState<RichText>(props.model.content);
  const [trigger, setTrigger] = React.useState(props.model.trigger);
  const [audioParams, setAudioParams] = React.useState({
    audioSrc: props.model.audioSrc,
    audioType: props.model.audioType,
  });

  const isTriggerMode = (mode: OverlayTriggerType) => mode === trigger;
  const onAudioChange = useCallback((src?: ContentModel.AudioSource) => {
    setAudioParams({
      audioSrc: src?.url,
      audioType: src?.contenttype,
    });
  }, []);

  const triggerSettings = (
    <div className="mb-3">
      <div>
        <label>
          <input
            type="radio"
            className="inline-block"
            onChange={() => setTrigger('hover')}
            checked={isTriggerMode('hover')}
          />
          <p className="ml-2 inline-block">
            <b>mouseover</b>
          </p>
        </label>
      </div>
      <div>
        <label>
          <input
            type="radio"
            className="inline-block"
            onChange={() => setTrigger('click')}
            checked={isTriggerMode('click')}
          />
          <p className="ml-2 inline-block">
            <b>click</b>
          </p>
        </label>
      </div>
    </div>
  );

  return (
    <div className="row ml-5 border border-dashed p-4" contentEditable={false}>
      <h2 className="text-lg">Popup Content</h2>
      <div className="col-span-12">
        <span className="mb-4">Shown to students when triggered on:</span>
        <div className="min-w-[600px]">
          {triggerSettings}

          <RichTextEditor
            editMode={true}
            projectSlug={props.commandContext.projectSlug}
            value={content}
            onEdit={(content) => setContent(content as RichText)}
            fixedToolbar={true}
            allowBlockElements={false}
          />

          <InlineAudioClipPicker
            commandContext={props.commandContext}
            clipSrc={audioParams.audioSrc}
            onChange={onAudioChange}
          >
            Audio to play
          </InlineAudioClipPicker>
          <button
            className="btn btn-primary"
            type="button"
            onClick={() => props.onDone({ content, trigger, ...audioParams })}
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
};
