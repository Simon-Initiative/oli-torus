/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import YouTube from 'react-youtube';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
// TODO: fix typing
const Video: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [videoIsPlayerStarted, setVideoIsPlayerStarted] = useState(false);
  const [videoIsCompleted, setVideoIsCompleted] = useState(false);
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
          key: 'exposureInPercentage',
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
      NotificationType.HISTORY_NAVIGATION,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [Video]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.HISTORY_NAVIGATION:
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
            // nothing to do
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
    x,
    y,
    z,
    width,
    height,
    src,
    alt,
    customCssClass,
    triggerCheck,
    autoPlay = false,
    startTime,
    endTime,
    enableReplay = true,
    subtitles,
  } = model;

  const videoStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };

  const youtubeRegex =
    /(?:https?:\/\/)?(?:youtu\.be\/|(?:www\.|m\.)?youtube\.com\/(?:watch|v|embed)(?:\.php)?(?:\?.*v=|\/))([a-zA-Z0-9_-]+)/;

  let finalSrc = src;
  let videoId = src;
  let isYoutubeSrc = false;

  const getYoutubeId = (url: any) => {
    const match = url.match(youtubeRegex);
    return match && match[1].length == 11 ? match[1] : false;
  };
  const youtubeOpts: any = {
    width: width?.toString(),
    height: height?.toString(),
    playerVars: {
      autoplay: autoPlay ? 1 : 0,
      loop: autoPlay ? 1 : 0,
      controls: enableReplay ? 1 : 0,
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
      if (endTime && endTime >= 0) {
        youtubeOpts.playerVars = {
          ...youtubeOpts.playerVars,
          end: endTime || 0,
        };
      }
    }
  } else {
    if (startTime && startTime >= 0) {
      finalSrc = `${finalSrc}#t=${startTime}`;
      if (endTime && endTime >= 0) {
        finalSrc = `${finalSrc},${endTime}`;
      }
    }
  }

  const handleVideoEnd = (data: any) => {
    setVideoIsPlayerStarted(true);
    saveState({
      isVideoPlayerStarted: true,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: true,
      videoState: 'completed',
    });
    if (triggerCheck) {
      props.onSubmit({ id: `${id}`, responses: [] });
    }
  };

  let isVideoStarted = false;
  const handleVideoPlay = (data: any) => {
    if (isVideoStarted) return;
    isVideoStarted = true;
    setVideoIsPlayerStarted(true);
    saveState({
      isVideoPlayerStarted: true,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: false,
      videoState: 'playing',
    });
  };

  const handleVideoPause = (data: any) => {
    setVideoIsPlayerStarted(true);
    saveState({
      isVideoPlayerStarted: true,
      currentTime: isYoutubeSrc ? data.target.getCurrentTime() : data.target.currentTime,
      duration: isYoutubeSrc ? data.target.getDuration() : data.target.duration,
      isVideoCompleted: false,
      videoState: 'paused',
    });
  };
  const saveState = ({
    isVideoPlayerStarted,
    currentTime,
    duration,
    isVideoCompleted,
    videoState,
  }: {
    isVideoPlayerStarted: boolean;
    currentTime: any;
    duration: any;
    isVideoCompleted: boolean;
    videoState: string;
  }) => {
    const currentVideoTime = parseFloat(currentTime || 0);
    const videoDuration = parseFloat(duration || 0);
    const exposureInPercentage = (currentVideoTime / videoDuration) * 100;
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
          key: 'exposureInPercentage',
          type: CapiVariableTypes.NUMBER,
          value: isNaN(exposureInPercentage) ? 0 : parseInt(exposureInPercentage.toString()),
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
      opts={youtubeOpts}
      onPlay={handleVideoPlay}
      onEnd={handleVideoEnd}
      onPause={handleVideoPause}
    />
  );

  const videoTag = (
    <video
      width={width}
      height={height}
      className={cssClass}
      autoPlay={autoPlay}
      loop={autoPlay}
      controls={enableReplay}
      onEnded={handleVideoEnd}
      onPlay={handleVideoPlay}
      onPause={handleVideoPause}
    >
      <source src={src} />
      {subtitles &&
        subtitles.length > 0 &&
        subtitles.map((subtitle: any) => {
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
    <div data-janus-type={props.type} style={videoStyles}>
      {elementTag}
    </div>
  ) : null;
};

export const tagName = 'janus-video';

export default Video;
