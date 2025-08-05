/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import YouTube, { Options } from 'react-youtube';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import { VideoModel } from './schema';

const Video: React.FC<PartComponentProps<VideoModel>> = (props) => {
  const [_state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(typeof props.model === 'string' ? {} : props.model);
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [videoIsPlayerStarted, setVideoIsPlayerStarted] = useState(false);
  const [_videoIsCompleted, setVideoIsCompleted] = useState(false);
  const [videoAutoPlay, setVideoAutoPlay] = useState(false);
  const [videoEnableReplay, setVideoEnableReplay] = useState(true);
  const [cssClass, setCssClass] = useState('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dCssClass = pModel.customCssClass || cssClass;
    setCssClass(dCssClass);

    const dAutoPlay = typeof pModel.autoPlay === 'boolean' ? pModel.autoPlay : videoAutoPlay;
    setVideoAutoPlay(dAutoPlay);

    const dEnableReplay =
      typeof pModel.enableReplay === 'boolean' ? pModel.enableReplay : videoEnableReplay;
    setVideoEnableReplay(dEnableReplay);

    const dStartTime = pModel.startTime || 0;
    const dEndTime = pModel.endTime || '';

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: videoIsPlayerStarted,
        },
        {
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: dAutoPlay,
        },
        {
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: dStartTime,
        },
        {
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: '',
        },
        {
          key: 'endTime',
          type: CapiVariableTypes.STRING,
          value: dEndTime,
        },
        {
          key: 'exposureInSeconds',
          type: CapiVariableTypes.NUMBER,
          value: dStartTime,
        },
        {
          key: 'exposurePercentage',
          type: CapiVariableTypes.NUMBER,
          value: 0,
        },
        {
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: dStartTime,
        },
        {
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: 'notStarted',
        },
        {
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: 0,
        },
        {
          key: 'enableReplay',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnableReplay,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;

    const sAutoPlay = currentStateSnapshot[`stage.${id}.autoPlay`];
    if (sAutoPlay !== undefined) {
      setVideoAutoPlay(sAutoPlay);
    }

    const sEnableReplay = currentStateSnapshot[`stage.${id}.enableReplay`];
    if (sEnableReplay !== undefined) {
      setVideoEnableReplay(sEnableReplay);
    }

    /* const sStartTime = currentStateSnapshot[`stage.${id}.startTime`];
    if (sStartTime !== undefined) {
      setStartTime(sStartTime);
    }
    const sEndTime = currentStateSnapshot[`stage.${id}.endTime`];
    if (sEndTime !== undefined) {
      setEndTime(sEndTime);
    } */

    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }
    setReady(true);
  }, []);

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [Video]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const sAutoPlay = changes[`stage.${id}.autoPlay`];
              if (sAutoPlay !== undefined) {
                setVideoAutoPlay(sAutoPlay);
              }

              const sEnableReplay = changes[`stage.${id}.enableReplay`];
              if (sEnableReplay !== undefined) {
                setVideoEnableReplay(sEnableReplay);
              }

              const sHasStarted = changes[`stage.${id}.hasStarted`];
              if (sHasStarted !== undefined) {
                setVideoIsPlayerStarted(sHasStarted);
              }

              const sHasCompleted = changes[`stage.${id}.hasCompleted`];
              if (sHasCompleted !== undefined) {
                setVideoIsCompleted(sHasCompleted);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;
              const sAutoPlay = changes[`stage.${id}.autoPlay`];
              if (sAutoPlay !== undefined) {
                setVideoAutoPlay(sAutoPlay);
              }

              const sEnableReplay = changes[`stage.${id}.enableReplay`];
              if (sEnableReplay !== undefined) {
                setVideoEnableReplay(sEnableReplay);
              }

              const sHasStarted = changes[`stage.${id}.hasStarted`];
              if (sHasStarted !== undefined) {
                setVideoIsPlayerStarted(sHasStarted);
              }

              const sHasCompleted = changes[`stage.${id}.hasCompleted`];
              if (sHasCompleted !== undefined) {
                setVideoIsCompleted(sHasCompleted);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const {
    width,
    height,
    src,
    triggerCheck,
    autoPlay = false,
    startTime = 0,
    endTime = 0,
    enableReplay = true,
    subtitles,
  } = model;

  const _videoStyles: CSSProperties = {
    /* position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z, */
  };

  const youtubeRegex =
    /(?:https?:\/\/)?(?:youtu\.be\/|(?:www\.|m\.)?youtube\.com\/(?:watch|v|embed)(?:\.php)?(?:\?.*v=|\/))([a-zA-Z0-9_-]+)/;

  let finalSrc = src;
  let videoId = src;
  let isYoutubeSrc = false;

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }

    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, height]);
  const getYoutubeId = (url: string) => {
    const match = url.match(youtubeRegex);
    return match && match[1].length == 11 ? match[1] : false;
  };
  const youtubeOpts: Options = {
    width: width ? width.toString() : '100%',
    height: height ? height.toString() : '100%',
    playerVars: {
      autoplay: autoPlay ? 1 : 0,
      loop: autoPlay ? 1 : 0,
      controls: !_videoIsCompleted || enableReplay ? 1 : 0,
      rel: 0, // Always limit related videos to same channel
    },
  };
  if (youtubeRegex.test(finalSrc)) {
    isYoutubeSrc = true;
    // If Youtube video, get ID and create embed url
    videoId = getYoutubeId(src);

    if (startTime && startTime >= 0) {
      youtubeOpts.playerVars = {
        ...youtubeOpts.playerVars,
        start: startTime || 0,
      };
    }
    if (endTime && endTime >= 0) {
      youtubeOpts.playerVars = {
        ...youtubeOpts.playerVars,
        end: endTime || 0,
      };
    }
  } else {
    finalSrc = `${finalSrc}#t=${startTime}${endTime > 0 ? `,${endTime}` : ''}`;
  }

  const handleVideoEnd = (data: any) => {
    setVideoIsCompleted(true);
    saveState({
      isVideoPlayerStarted: videoIsPlayerStarted,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: true,
      videoState: 'completed',
    });
    if (triggerCheck) {
      props.onSubmit({ id: `${id}`, responses: [] });
    }
  };

  const handleVideoPlay = (data: any) => {
    setVideoIsPlayerStarted(true);
    saveState({
      isVideoPlayerStarted: true,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: _videoIsCompleted,
      videoState: 'playing',
    });
  };

  const handleVideoPause = (data: any) => {
    saveState({
      isVideoPlayerStarted: videoIsPlayerStarted,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: _videoIsCompleted,
      videoState: 'paused',
    });
  };
  const saveState = ({
    isVideoPlayerStarted,
    currentTime = '0',
    duration = '0',
    isVideoCompleted,
    videoState,
  }: {
    isVideoPlayerStarted: boolean;
    currentTime: string;
    duration: string;
    isVideoCompleted: boolean;
    videoState: string;
  }) => {
    const currentVideoTime = parseFloat(currentTime);
    const videoDuration = parseFloat(duration);
    const exposurePercentage = (currentVideoTime / videoDuration) * 100;
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: isVideoPlayerStarted,
        },
        {
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: videoAutoPlay,
        },
        {
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: duration,
        },
        {
          key: 'endTime',
          type: CapiVariableTypes.STRING,
          value: endTime || '',
        },
        {
          key: 'exposureInSeconds',
          type: CapiVariableTypes.NUMBER,
          value: currentTime,
        },
        {
          key: 'exposurePercentage',
          type: CapiVariableTypes.NUMBER,
          value: isNaN(exposurePercentage) ? 0 : parseInt(exposurePercentage.toString()),
        },
        {
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: isVideoCompleted,
        },
        {
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: startTime || 0,
        },
        {
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: videoState,
        },
        {
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          key: 'enableReplay',
          type: CapiVariableTypes.BOOLEAN,
          value: videoEnableReplay,
        },
      ],
    });
  };

  const iframeTag = (
    <YouTube
      videoId={videoId}
      containerClassName="react-youtube-container"
      opts={youtubeOpts}
      onPlay={handleVideoPlay}
      onEnd={handleVideoEnd}
      onPause={handleVideoPause}
    />
  );

  const srcAsWebm =
    finalSrc?.substring(0, finalSrc?.lastIndexOf('.')) +
    `.webm#t=${startTime}${endTime > 0 ? `,${endTime}` : ''}`;

  const videoTag = (
    <video
      width="100%"
      height="100%"
      /* className={cssClass} */
      autoPlay={autoPlay}
      controls={!_videoIsCompleted || enableReplay}
      onEnded={handleVideoEnd}
      onPlay={handleVideoPlay}
      onPause={handleVideoPause}
    >
      <source src={finalSrc} />
      <source src={srcAsWebm} />
      {subtitles &&
        subtitles.length > 0 &&
        subtitles.map((subtitle: { src: string; language: string; default: boolean }) => {
          const defaults = subtitles.length === 1 ? true : subtitle.default;
          return (
            <track
              key={subtitle.src}
              src={subtitle.src}
              srcLang={subtitle.language}
              label={subtitle.language}
              kind="subtitles"
              default={defaults || false}
            />
          );
        })}
    </video>
  );

  const elementTag = youtubeRegex.test(src) ? iframeTag : videoTag;
  return ready ? (
    <div data-janus-type={tagName} style={{ width: '100%', height: '100%' }}>
      <style>
        {`
          .react-youtube-container {
            width: 100%;
            height: 100%
          }
        `}
      </style>
      {elementTag}
    </div>
  ) : null;
};

export const tagName = 'janus-video';

export default Video;
