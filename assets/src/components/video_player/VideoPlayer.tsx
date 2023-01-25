import React, { ReactNode, useCallback, useRef } from 'react';
import * as ContentModel from '../../data/content/model/elements/types';

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
import { ClosedCaptionButton } from './ClosedCaptionButton';

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

const isValidSize = (video: ContentModel.Video) =>
  video.width && video.height && video.width > 0 && video.height > 0;

interface VideoInterface {
  play: () => void;
  seek: (time: number) => void;
}

export const VideoPlayer: React.FC<{ video: ContentModel.Video; children?: ReactNode }> =
  React.memo(({ video, children }) => {
    const playerRef = useRef(null);
    const pauseAtPosition = useRef(-1);
    const sizeAttributes = isValidSize(video)
      ? { width: video.width, height: video.height, fluid: false }
      : { fluid: true };

    const hasCaptions = video.captions && video.captions.length > 0;

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

    const preventDefault = useCallback((e) => {
      e.preventDefault(); // fixes https://eliterate.atlassian.net/browse/MER-1503
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
      <div
        className="video-player"
        aria-role="img"
        aria-roledescription="Video Player"
        aria-aria-label={video.alt}
        onClick={preventDefault}
      >
        <Player poster={video.poster} {...sizeAttributes} ref={onPlayer} crossOrigin="anonymous">
          {/* Hide the video-react big play button so we can render our own that fits with our icon styles */}
          <BigPlayButton className="big-play-button-hide" />
          <InitialPlayButton />

          {video.src.map((src) => (
            <source key={src.url} src={src.url} type={src.contenttype} />
          ))}
          {video.captions?.map((caption, idx) => (
            <track
              key={idx}
              src={caption.src}
              kind="captions"
              label={caption.label}
              srcLang={caption.language_code}
            />
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
            {hasCaptions && <ClosedCaptionButton order={10} />}
          </ControlBar>
        </Player>
        {children}
      </div>
    );
  });

VideoPlayer.displayName = 'VideoPlayer';
