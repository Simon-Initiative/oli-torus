import React, { useCallback, useRef } from 'react';
import { Video } from '../../data/content/model/elements/types';

import {
  BigPlayButton,
  Player,
  ControlBar,
  CurrentTimeDisplay,
  TimeDivider,
  DurationDisplay,
  ProgressControl,
  PlayerState,
  PlaybackRateMenuButton,
} from 'video-react';

import { MuteButton } from './VideoMuteButton';
import { InitialPlayButton } from './InitialPlayButton';
import { PlayButton } from './VideoPlayButton';
import { FullScreenButton } from './VideoFullScreenButton';
import { useCommandTarget } from '../editing/elements/command_button/useCommandTarget';

const startEndCueRegex = /startcuepoint=([0-9.]+);endcuepoint=([0-9.]+)/;
const startCueRegex = /startcuepoint=([0-9.]+)/;

export const parseVideoPlayCommand = (command: string) => {
  if (startEndCueRegex.test(command)) {
    const matches = command.match(startEndCueRegex);
    if (matches) {
      return {
        start: parseFloat(matches[1]),
        end: parseFloat(matches[2]),
      };
    }
  }
  if (startCueRegex.test(command)) {
    const matches = command.match(startCueRegex);
    if (matches) {
      return {
        start: parseFloat(matches[1]),
        end: -1,
      };
    }
  }

  return { start: -1, end: -1 };
};

const isValidSize = (video: Video) =>
  video.width && video.height && video.width > 0 && video.height > 0;

interface VideoInterface {
  play: () => void;
  seek: (time: number) => void;
}

export const VideoPlayer: React.FC<{ video: Video }> = React.memo(({ video }) => {
  const playerRef = useRef(null);
  const pauseAtPosition = useRef(-1);
  const sizeAttributes = isValidSize(video)
    ? { width: video.width, height: video.height, fluid: false }
    : { fluid: true };

  const onPlayer = useCallback((player) => {
    playerRef.current = player;

    if (!player) {
      return;
    }
    // This handles stopping at the correct point if a cue-point command previously came in with an end-timestamp set.
    player.subscribeToStateChange((state: PlayerState) => {
      if (
        pauseAtPosition.current > 0 &&
        state.hasStarted &&
        state.currentTime >= pauseAtPosition.current
      ) {
        pauseAtPosition.current = -1;
        player.pause();
      }
    });
  }, []);

  const onCommandReceived = useCallback((message: string) => {
    if (!playerRef.current) return;
    const player = playerRef.current as VideoInterface;
    const { start, end } = parseVideoPlayCommand(message);
    pauseAtPosition.current = end;
    if (start >= 0) {
      player.seek(start);
      player.play();
    }
  }, []);

  useCommandTarget(video.id, onCommandReceived);

  return (
    <div className="video-player">
      <Player poster={video.poster} {...sizeAttributes} ref={onPlayer}>
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
          <PlaybackRateMenuButton key="playback-spoeed" order={8} />
          <FullScreenButton key="fullscreen-toggle" order={9} />
        </ControlBar>
      </Player>
    </div>
  );
});

VideoPlayer.displayName = 'VideoPlayer';
