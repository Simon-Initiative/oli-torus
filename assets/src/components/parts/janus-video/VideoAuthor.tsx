import React, { useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { VideoModel } from './schema';

const VideoAuthor: React.FC<AuthorPartComponentProps<VideoModel>> = (props) => {
  const { model } = props;

  const { height } = model;
  const subtitles = Array.isArray(model.subtitles)
    ? model.subtitles
    : model.subtitles && typeof model.subtitles === 'object'
    ? [model.subtitles]
    : [];
  const subtitleCount = subtitles.filter((s: any) => s?.src).length;

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div
      data-janus-type={tagName}
      style={{
        position: 'relative',
        width: props.model.width || '100%',
        height: height,
        background: 'black',
        textAlign: 'center',
      }}
    >
      <style>
        {`
          .fa-video {
            top: calc(50% - 10px)
          }
        `}
      </style>
      <i
        className="fas fa-video fa-lg"
        style={{
          color: 'white',
          position: 'relative',
        }}
      ></i>
      {subtitleCount > 0 && (
        <div
          style={{
            position: 'absolute',
            bottom: '8px',
            right: '8px',
            color: 'white',
            fontSize: '12px',
            background: 'rgba(0, 0, 0, 0.5)',
            border: '1px solid rgba(255, 255, 255, 0.35)',
            borderRadius: '4px',
            padding: '2px 6px',
          }}
        >
          {subtitleCount} subtitle{subtitleCount > 1 ? 's' : ''}
        </div>
      )}
    </div>
  );
};

export const tagName = 'janus-video';

export default VideoAuthor;
