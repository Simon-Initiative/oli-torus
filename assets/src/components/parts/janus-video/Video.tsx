/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import YouTube from 'react-youtube';
import { CapiVariable } from '../types/parts';

// TODO: fix typing
const Video: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id = props.id;

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

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
  const [videoIsPlayerStarted, setVideoIsPlayerStarted] = useState(false);
  const [videoIsCompleted, setVideoIsCompleted] = useState(false);
  const [videoAutoPlay, setVideoAutoPlay] = useState(autoPlay);
  const [videoEnableReplay, setVideoEnableReplay] = useState(enableReplay);
  const youtubeRegex = /(?:https?:\/\/)?(?:youtu\.be\/|(?:www\.|m\.)?youtube\.com\/(?:watch|v|embed)(?:\.php)?(?:\?.*v=|\/))([a-zA-Z0-9_-]+)/;

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

  useEffect(() => {
    props.onReady({
      activityId: `${id}`,
      partResponses: [
        {
          id: `${id}.hasStarted`,
          key: 'hasStarted',
          type: 4,
          value: videoIsPlayerStarted,
        },
        {
          id: `${id}.autoPlay`,
          key: 'autoPlay',
          type: 4,
          value: videoAutoPlay,
        },
        {
          id: `${id}.currentTime`,
          key: 'currentTime',
          type: 2,
          value: startTime,
        },
        {
          id: `${id}.duration`,
          key: 'duration',
          type: 2,
          value: '',
        },
        {
          id: `${id}.endTime`,
          key: 'endTime',
          type: 2,
          value: endTime || '',
        },
        {
          id: `${id}.exposureInSeconds`,
          key: 'exposureInSeconds',
          type: 1,
          value: startTime,
        },
        {
          id: `${id}.exposureInPercentage`,
          key: 'exposureInPercentage',
          type: 1,
          value: 0,
        },
        {
          id: `${id}.hasCompleted`,
          key: 'hasCompleted',
          type: 4,
          value: false,
        },
        {
          id: `${id}.startTime`,
          key: 'startTime',
          type: 2,
          value: startTime || 0,
        },
        {
          id: `${id}.state`,
          key: 'state',
          type: 2,
          value: 'notStarted',
        },
        {
          id: `${id}.totalSecondsWatched`,
          key: 'totalSecondsWatched',
          type: 2,
          value: startTime,
        },
        {
          id: `${id}.enableReplay`,
          key: 'enableReplay',
          type: 4,
          value: videoEnableReplay,
        },
      ],
    });
  }, []);

  useEffect(() => {
    handleStateChange(state);
  }, [state]);

  const handleStateChange = (stateData: CapiVariable[]) => {
    // override various things from state
    const CapiVariables: any = {
      isVideoPlayerStarted: videoIsPlayerStarted,
      currentTime: startTime,
      duration: '',
      isVideoCompleted: false,
      videoState: 'notStarted',
    };
    const interested = stateData.filter((stateVar) => stateVar.id.indexOf(`${id}.`) === 0);
    interested.forEach((stateVar) => {
      if (stateVar.key === 'hasStarted') {
        setVideoIsPlayerStarted(stateVar.value as boolean);
        CapiVariables.isVideoPlayerStarted = stateVar.value as boolean;
      }
      if (stateVar.key === 'currentTime') {
        CapiVariables.currentTime = stateVar.value as number;
      }
      if (stateVar.key === 'duration') {
        CapiVariables.duration = stateVar.value as number;
      }
      if (stateVar.key === 'hasCompleted') {
        setVideoIsCompleted(stateVar.value as boolean);
        CapiVariables.isVideoCompleted = stateVar.value as boolean;
      }
      if (stateVar.key === 'state') {
        CapiVariables.videoState = stateVar.value as string;
      }
      if (stateVar.key === 'autoPlay') {
        setVideoAutoPlay(stateVar.value as boolean);
      }
      if (stateVar.key === 'enableReplay') {
        setVideoEnableReplay(stateVar.value as boolean);
      }
    });
    saveState(CapiVariables);
  };

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
      props.onSubmit({ Id: `${id}`, partResponses: [] });
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
      activityId: `${id}`,
      partResponses: [
        {
          id: `${id}.hasStarted`,
          key: 'hasStarted',
          type: 4,
          value: isVideoPlayerStarted,
        },
        {
          id: `${id}.autoPlay`,
          key: 'autoPlay',
          type: 4,
          value: videoAutoPlay,
        },
        {
          id: `stage.${id}.currentTime`,
          key: 'currentTime',
          type: 2,
          value: currentTime,
        },
        {
          id: `${id}.duration`,
          key: 'duration',
          type: 2,
          value: duration,
        },
        {
          id: `${id}.endTime`,
          key: 'endTime',
          type: 2,
          value: endTime || '',
        },
        {
          id: `${id}.exposureInSeconds`,
          key: 'exposureInSeconds',
          type: 1,
          value: currentTime,
        },
        {
          id: `${id}.exposureInPercentage`,
          key: 'exposureInPercentage',
          type: 1,
          value: isNaN(exposureInPercentage) ? 0 : parseInt(exposureInPercentage.toString()),
        },
        {
          id: `${id}.hasCompleted`,
          key: 'hasCompleted',
          type: 4,
          value: isVideoCompleted,
        },
        {
          id: `${id}.startTime`,
          key: 'startTime',
          type: 2,
          value: startTime || 0,
        },
        {
          id: `${id}.state`,
          key: 'state',
          type: 2,
          value: videoState,
        },
        {
          id: `${id}.totalSecondsWatched`,
          key: 'totalSecondsWatched',
          type: 2,
          value: currentTime,
        },
        {
          id: `${id}.enableReplay`,
          key: 'enableReplay',
          type: 4,
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
      className={customCssClass}
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
  return (
    <div data-janus-type={props.type} style={videoStyles}>
      {elementTag}
    </div>
  );
};

export const tagName = 'janus-video';

export default Video;
