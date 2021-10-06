import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { VideoModel } from './schema';

const VideoAuthor: React.FC<AuthorPartComponentProps<VideoModel>> = (props) => {
  const { model } = props;

  const { x, y, z, width, src } = model;

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div data-janus-type={tagName} style={{ width: '100%', height: '100%' }}>
      <style>
        {`
          .react-youtube-container {
            width: 100%;
            height: 100%
          }
        `}
      </style>
      <video
        width="100%"
        height="100%"
        /* className={cssClass} */
        controls={true}
      >
        <source src={src} />
      </video>
    </div>
  );
};

export const tagName = 'janus-video';

export default VideoAuthor;
