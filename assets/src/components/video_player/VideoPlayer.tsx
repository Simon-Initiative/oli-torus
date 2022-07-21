import React from 'react';
import { Video } from '../../data/content/model/elements/types';

import {
  BigPlayButton,
  Player,
  ControlBar,
  CurrentTimeDisplay,
  TimeDivider,
  DurationDisplay,
  ProgressControl,
} from 'video-react';

import { MuteButton } from './VideoMuteButton';
import { InitialPlayButton } from './InitialPlayButton';
import { PlayButton } from './VideoPlayButton';
import { FullScreenButton } from './VideoFullScreenButton';

const isValidSize = (video: Video) =>
  video.width && video.height && video.width > 0 && video.height > 0;

export const VideoPlayer: React.FC<{ video: Video }> = React.memo(({ video }) => {
  const sizeAttributes = isValidSize(video)
    ? { width: video.width, height: video.height, fluid: false }
    : { fluid: true };

  return (
    <div className="video-player">
      <Player poster={video.poster} {...sizeAttributes}>
        {/* Hide the video-react big play button so we can render our own that fits with our icon styles */}
        <BigPlayButton className="big-play-button-hide" />
        <InitialPlayButton />

        {video.src.map((src) => (
          <source key={src.url} src={src.url} type={src.contenttype} />
        ))}
        <ControlBar disableDefaultControls={true} autoHide={true} className="control-bar">
          <PlayButton key="play-toggle" order={1} />
          <MuteButton key="volume-menu-button" order={4} />
          <CurrentTimeDisplay key="current-time-display" order={5.1} />
          <TimeDivider key="time-divider" order={5.2} />
          <DurationDisplay key="duration-display" order={5.3} />
          <ProgressControl key="progress-control" order={6} />
          <FullScreenButton key="fullscreen-toggle" order={8} />
        </ControlBar>
      </Player>
    </div>
  );
});

VideoPlayer.displayName = 'VideoPlayer';
