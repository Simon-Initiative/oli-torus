import React from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import { Video } from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';

import { VideoPlayer } from '../../../video_player/VideoPlayer';
import { VideoPlaceholder } from './VideoPlaceholder';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { useElementSelected } from '../../../../data/content/utils';
import { VideoSettings } from './VideoSettings';

interface Props extends EditorProps<Video> {}

export const VideoEditor = (props: Props) => {
  const { model } = props;
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();

  if (!model.src || model.src.length === 0) {
    return <VideoPlaceholder {...props} />;
  }

  return (
    <span {...props.attributes} contentEditable={false}>
      {props.children}
      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={selected}
        align="start"
        position="top"
        content={
          <VideoSettings
            model={props.model}
            onEdit={onEdit}
            commandContext={props.commandContext}
          />
        }
      >
        <VideoPlayer video={model} />
      </HoverContainer>
    </span>
  );
};
