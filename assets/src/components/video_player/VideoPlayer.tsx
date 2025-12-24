import React, { ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import {
  BigPlayButton,
  ControlBar,
  CurrentTimeDisplay,
  DurationDisplay,
  PlaybackRateMenuButton,
  Player,
  PlayerState,
  ProgressControl,
  Shortcut,
  TimeDivider,
} from 'video-react';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
import * as XAPI from 'data/persistence/xapi';
import * as ContentModel from '../../data/content/model/elements/types';
import { useCommandTarget } from '../editing/elements/command_button/useCommandTarget';
import { ClosedCaptionButton } from './ClosedCaptionButton';
import { InitialPlayButton } from './InitialPlayButton';
import { FullScreenButton } from './VideoFullScreenButton';
import { MuteButton } from './VideoMuteButton';
import { PlayButton } from './VideoPlayButton';

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

export const VideoPlayer: React.FC<{
  video: ContentModel.Video;
  pageAttemptGuid: string;
  pointMarkerContext?: PointMarkerContext;
  children?: ReactNode;
}> = React.memo(({ video, pointMarkerContext, children, pageAttemptGuid }) => {
  const playerRef = useRef(null);
  const pauseAtPosition = useRef(-1);
  const [seekFrom, setSeekFrom] = useState(0);
  const [segments, setSegments] = useState([] as XAPI.PlayedSegment[]);
  const segmentsRef = useRef(segments);
  const seekFromRef = useRef(seekFrom);

  const sizeAttributes = isValidSize(video)
    ? { width: video.width, height: video.height, fluid: false }
    : { fluid: true };

  const hasCaptions = video.captions && video.captions.length > 0;

  // Update segmentsRef whenever segments change
  useEffect(() => {
    segmentsRef.current = segments;
  }, [segments]);

  useEffect(() => {
    seekFromRef.current = seekFrom;
  }, [seekFrom]);

  const onPlayer = useCallback((player) => {
    playerRef.current = player;

    if (!player) {
      return;
    }
    // This handles stopping at the correct point if a cue-point command previously came in with an end-timestamp set.

    // For suppressing keyboard shortcuts while letting keyboard events through: AI-generated solution stops
    // player from ever being "active" to the Shortcut component so latter doesn't consume keyboard evts
    const actions = player.manager?.getActions?.();
    actions?.activate(false);
    actions?.userActivate(false);

    player.subscribeToStateChange((state: PlayerState, prev: PlayerState) => {
      // to suppress shortcuts: immediately undo any change of player state to "active"
      if (state.isActive) {
        actions?.activate(false);
        actions?.userActivate(false);
      }

      if (
        pauseAtPosition.current > 0 &&
        state.hasStarted &&
        state.currentTime >= pauseAtPosition.current
      ) {
        pauseAtPosition.current = -1;
        player.pause();
      }

      // In an authoring context, just stop here, we don't want to emit xAPI events
      if (pageAttemptGuid === '') {
        return;
      }

      if (state.seekingTime !== 0 && prev.seekingTime === 0) {
        const lastSegment = segmentsRef.current[segmentsRef.current.length - 1];

        if (lastSegment) {
          lastSegment.end = state.seekingTime;
          segmentsRef.current[segmentsRef.current.length - 1] = lastSegment;
          setSegments(segmentsRef.current);
        }

        setSeekFrom(prev.currentTime);
      } else if (!state.seeking && prev.seeking) {
        const segment = { start: state.currentTime, end: null };
        setSegments([...segmentsRef.current, segment]);

        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_seeked',
            category: 'video',
            event_type: 'seeked',
            video_url: state.currentSrc,
            video_title: state.currentSrc,
            video_seek_to: state.currentTime,
            video_seek_from: seekFromRef.current,
            content_element_id: video.id,
          } as XAPI.VideoSeekedEvent,
        );
      } else if (state.ended && !prev.ended) {
        const lastSegment = segmentsRef.current[segmentsRef.current.length - 1];
        if (lastSegment) {
          lastSegment.end = state.currentTime;
        }
        const segments = segmentsRef.current;
        segments[segments.length - 1] = lastSegment;

        const progress = XAPI.calculateProgress(segments, state.duration);

        // Emit completed event
        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_completed',
            category: 'video',
            event_type: 'completed',
            video_url: state.currentSrc,
            video_title: state.currentSrc,
            video_length: state.duration,
            video_played_segments: XAPI.formatSegments(segments),
            video_progress: progress,
            video_time: state.currentTime,
            content_element_id: video.id,
          } as XAPI.VideoCompletedEvent,
        );
      } else if (state.paused && !prev.paused) {
        const lastSegment = segmentsRef.current[segmentsRef.current.length - 1];
        let segmentsStr = '';

        if (lastSegment) {
          lastSegment.end = state.currentTime;
          const segments = segmentsRef.current;
          segments[segments.length - 1] = lastSegment;
          setSegments(segments);
          segmentsStr = XAPI.formatSegments(segments);
        }

        // Emit paused event
        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_paused',
            category: 'video',
            event_type: 'paused',
            video_url: state.currentSrc,
            video_title: state.currentSrc,
            video_length: state.duration,
            video_played_segments: segmentsStr,
            video_progress: XAPI.calculateProgress(segments, state.duration),
            video_time: state.currentTime,
            content_element_id: video.id,
          } as XAPI.VideoPausedEvent,
        );
      } else if (!state.paused && prev.paused) {
        const segment = { start: state.currentTime, end: null };
        setSegments([...segmentsRef.current, segment]);

        // Emit played event
        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_played',
            category: 'video',
            event_type: 'played',
            video_url: state.currentSrc,
            video_title: state.currentSrc,
            video_length: state.duration,
            video_play_time: state.currentTime,
            content_element_id: video.id,
          } as XAPI.VideoPlayedEvent,
        );
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
      aria-label={video.alt?.trim() || undefined}
      onClick={preventDefault}
      {...maybePointMarkerAttr(video, pointMarkerContext)}
    >
      <Player poster={video.poster} {...sizeAttributes} ref={onPlayer} crossOrigin="anonymous">
        {/* To suppress keyboard shortcuts: use custom Shortcut component to override builtin default */}
        {/* Still need to suppress player ever activating to prevent keystrokes from being consumed */}
        <Shortcut clickable={false} dblclickable={false} shortcuts={[]} />
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
