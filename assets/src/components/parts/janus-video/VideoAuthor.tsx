import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { VideoModel } from './schema';

const VideoAuthor: React.FC<AuthorPartComponentProps<VideoModel>> = (props) => {
  const { model } = props;

  const { x, y, z, width, src, height } = model;

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div
      data-janus-type={tagName}
      style={{ width: '100%', height: height, background: 'black', textAlign: 'center' }}
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
    </div>
  );
};

export const tagName = 'janus-video';

export default VideoAuthor;
