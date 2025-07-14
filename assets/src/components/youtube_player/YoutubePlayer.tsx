import React, { useCallback, useEffect, useRef, useState } from 'react';
import YouTube, { Options } from 'react-youtube';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { useCommandTarget } from 'components/editing/elements/command_button/useCommandTarget';
import { CUTE_OTTERS } from 'components/editing/elements/youtube/YoutubeElement';
import { parseVideoPlayCommand } from 'components/video_player/VideoPlayer';
import * as ContentModel from 'data/content/model/elements/types';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
import { WriterContext, defaultWriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import * as XAPI from 'data/persistence/xapi';

interface Player {
  seekTo: (time: number) => void;
  playVideo: () => void;
  pauseVideo: () => void;
  getPlayerState: () => number;
  getCurrentTime: () => number;
}

export const YoutubePlayer: React.FC<{
  video: ContentModel.YouTube;
  children?: React.ReactNode;
  context?: WriterContext;
  pageAttemptGuid: string;
  authorMode: boolean;
  pointMarkerContext?: PointMarkerContext;
}> = ({ video, children, authorMode, context, pointMarkerContext, pageAttemptGuid }) => {
  const stopInterval = useRef<number | undefined>();
  const [videoTarget, setVideoTarget] = useState<Player | null>(null);
  const segments = useRef<XAPI.PlayedSegment[]>([]);
  const url = useRef<string>('');
  const duration = useRef<number>(0);
  const pauseAtPosition = useRef(video.endTime || -1);
  const videoId = video.src || CUTE_OTTERS;
  const youTubeRef = useRef<YouTube>(null);
  context = context || defaultWriterContext();

  const opts: Options = authorMode
    ? {
        width: video.width ? `${video.width}px` : '100%',
        height: '100%',
        playerVars: {
          start: video.startTime,
          disablekb: 1,
          modestbranding: 1,
          showinfo: 0,
          rel: 0, // Always limit related videos to same channel
          controls: 0,
        },
      }
    : {
        width: video.width ? `${video.width}px` : '100%',
        height: '100%',
        playerVars: {
          start: video.startTime,
          rel: 0, // Always limit related videos to same channel
        },
      };

  const onReady = useCallback((event) => {
    setVideoTarget(event.target);

    (youTubeRef.current as any)
      .getInternalPlayer()
      .getDuration()
      .then((d: number) => {
        duration.current = d;
      });
    (youTubeRef.current as any)
      .getInternalPlayer()
      .getVideoUrl()
      .then((u: string) => (url.current = u));
  }, []);

  const stopAtTime = useCallback(() => {
    if (!videoTarget) return;
    const endTimeIsBeforeStartTime = video.endTime && video.endTime < (video.startTime || 0);

    if (authorMode || endTimeIsBeforeStartTime) {
      if (stopInterval.current) {
        clearInterval(stopInterval.current);
      }
      return;
    }
    const state = videoTarget.getPlayerState();
    const time = videoTarget.getCurrentTime();

    // console.info({
    //   endTimeIsAfterStartTime: endTimeIsBeforeStartTime,
    //   endTime: video.endTime,
    //   startTime: video.startTime,
    //   pauseAtPosition: pauseAtPosition.current,
    //   time,
    // });
    if (state === 1 && pauseAtPosition.current > 0 && time >= pauseAtPosition.current) {
      pauseAtPosition.current = -1;
      videoTarget.pauseVideo();
      if (stopInterval.current) {
        clearInterval(stopInterval.current);
      }
    }
  }, [authorMode, video.endTime, video.startTime, videoTarget]);

  const onStateChange = (e: any) => {
    if (!videoTarget || pageAttemptGuid == '') return;

    switch (e.data) {
      case 0:
        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_completed',
            category: 'video',
            event_type: 'completed',
            video_url: url.current,
            video_title: url.current,
            video_length: duration.current,
            video_played_segments: XAPI.formatSegments(segments.current),
            video_progress: XAPI.calculateProgress(segments.current, duration.current),
            video_time: videoTarget.getCurrentTime(),
            content_element_id: video.id,
          } as XAPI.VideoCompletedEvent,
        );
        break;
      case 1:
        const segment = { start: videoTarget.getCurrentTime(), end: null };
        segments.current.push(segment);

        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_played',
            category: 'video',
            event_type: 'played',
            video_url: url.current,
            video_title: url.current,
            video_length: duration.current,
            video_play_time: videoTarget.getCurrentTime(),
            content_element_id: video.id,
          } as XAPI.VideoPlayedEvent,
        );
        break;
      case 2:
        const lastSegment = segments.current[segments.current.length - 1];
        lastSegment.end = videoTarget.getCurrentTime();
        segments.current[segments.current.length - 1] = lastSegment;

        XAPI.emit_delivery(
          {
            type: 'page_video_key',
            page_attempt_guid: pageAttemptGuid,
          },
          {
            type: 'video_paused',
            category: 'video',
            event_type: 'paused',
            video_url: url.current,
            video_title: url.current,
            video_length: duration.current,
            video_played_segments: XAPI.formatSegments(segments.current),
            video_progress: XAPI.calculateProgress(segments.current, duration.current),
            video_time: videoTarget.getCurrentTime(),
            content_element_id: video.id,
          } as XAPI.VideoPausedEvent,
        );
        break;
    }
  };

  const onCommandReceived = useCallback(
    (message: string) => {
      if (!videoTarget) return;

      const { start, end } = parseVideoPlayCommand(message);
      pauseAtPosition.current = end;
      if (start >= 0) {
        if (stopInterval.current) {
          clearInterval(stopInterval.current);
        }
        stopInterval.current = window.setInterval(stopAtTime, 100);
        videoTarget.seekTo(start);
        videoTarget.playVideo();
      }
    },
    [stopAtTime, videoTarget],
  );

  useEffect(() => {
    if (video.endTime) {
      pauseAtPosition.current = video.endTime || -1;
      stopInterval.current = window.setInterval(stopAtTime, 100);
    }
    return () => {
      if (stopInterval.current) {
        clearInterval(stopInterval.current);
      }
    };
  }, [stopAtTime, video.endTime, video.startTime]);

  useCommandTarget(video.id, onCommandReceived);

  return (
    <ErrorBoundary errorMessage={<YoutubeError videoId={videoId} />}>
      <div
        className="embed-responsive embed-responsive-16by9"
        data-video-id={videoId}
        {...maybePointMarkerAttr(video, pointMarkerContext)}
      >
        <YouTube
          ref={youTubeRef}
          className="embed-responsive-item"
          videoId={videoId}
          opts={opts}
          onReady={onReady}
          onStateChange={onStateChange}
        />
      </div>
      {!authorMode && video.caption && (
        <div className="text-center">
          <HtmlContentModelRenderer content={video.caption} context={context} />
        </div>
      )}

      {children}
    </ErrorBoundary>
  );
};

const YoutubeError: React.FC<{ videoId: string }> = ({ videoId }) => (
  <>
    <p className="mb-4">Could not play YouTube video. Please refresh the page and try again.</p>
    <p>
      Alternatively, you can view the{' '}
      <a target="_blank" href={`https://www.youtube.com/watch?v=${videoId}`} rel="noreferrer">
        video directly on YouTube
      </a>
      .
    </p>

    <hr />

    <p>If the problem persists, contact support with the following details:</p>
  </>
);

YoutubePlayer.displayName = 'YoutubePlayer';
