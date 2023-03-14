import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { updateModel } from 'components/editing/elements/utils';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { useSlate } from 'slate-react';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { AudioToolbar } from './AudioSettings';
export interface AudioProps extends EditorProps<ContentModel.Audio> {}

export const AudioEditor = (props: AudioProps) => {
  const editor = useSlate();

  const onEdit = (updated: Partial<ContentModel.Audio>) =>
    updateModel<ContentModel.Audio>(editor, props.model, updated);

  return (
    <div {...props.attributes} contentEditable={false} className="m-4 pl-4 pr-4 text-center">
      {props.children}
      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={true}
        align="start"
        position="top"
        content={
          <AudioToolbar
            commandContext={props.commandContext}
            model={props.model}
            onEdit={onEdit}
            projectSlug={props.commandContext.projectSlug}
          />
        }
      >
        <audio src={props.model.src} controls />
        <CaptionEditor
          onEdit={(caption) => onEdit({ caption })}
          model={props.model}
          commandContext={props.commandContext}
        />
      </HoverContainer>
    </div>
  );
};
