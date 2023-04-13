import React from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import { Video } from 'data/content/model/elements/types';
import { useElementSelected } from '../../../../data/content/utils';
import { VideoPlayer } from '../../../video_player/VideoPlayer';
import { useCommandTargetable } from '../command_button/useCommandTargetable';
import { VideoCommandEditor } from './VideoCommandEditor';
import { VideoPlaceholder } from './VideoPlaceholder';
import { VideoSettings } from './VideoSettings';

interface Props extends EditorProps<Video> {}

export const VideoEditor = (props: Props) => {
  const { model } = props;
  const onEdit = useEditModelCallback(model);
  const _selected = useElementSelected();
  useCommandTargetable(
    model.id,
    'Video Player',
    model?.src[0]?.url || 'No video file selected',
    VideoCommandEditor,
  );

  if (!model.src || model.src.length === 0) {
    return <VideoPlaceholder {...props} />;
  }

  return (
    <span {...props.attributes} contentEditable={false} style={{ position: 'relative' }}>
      {props.children}

      <VideoPlayer video={model}>
        <VideoSettings model={props.model} onEdit={onEdit} commandContext={props.commandContext} />
      </VideoPlayer>
    </span>
  );
};
