/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import YouTube from 'react-youtube';
import { CapiVariable } from '../types/parts';
import { CapiVariableTypes } from '../../../adaptivity/capi';
// TODO: fix typing
const Video: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

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
    props.onInit({
      id,
      responses: [
        {
          id: `hasStarted`,
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: videoIsPlayerStarted,
        },
        {
          id: `autoPlay`,
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: videoAutoPlay,
        },
        {
          id: `currentTime`,
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: startTime,
        },
        {
          id: `duration`,
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: '',
        },
        {
          id: `endTime`,
          key: 'endTime',
          type: CapiVariableTypes.STRING,
          value: endTime || '',
        },
        {
          id: `exposureInSeconds`,
          key: 'exposureInSeconds',
          type: CapiVariableTypes.NUMBER,
          value: startTime,
        },
        {
          id: `exposureInPercentage`,
          key: 'exposureInPercentage',
          type: CapiVariableTypes.NUMBER,
          value: 0,
        },
        {
          id: `hasCompleted`,
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          id: `startTime`,
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: startTime || 0,
        },
        {
          id: `state`,
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: 'notStarted',
        },
        {
          id: `totalSecondsWatched`,
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: startTime,
        },
        {
          id: `enableReplay`,
          key: 'enableReplay',
          type: CapiVariableTypes.BOOLEAN,
          value: videoEnableReplay,
        },
      ],
    });
    setReady(true);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

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
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
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
    const interested = stateData.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
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
          id: `hasStarted`,
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: isVideoPlayerStarted,
        },
        {
          id: `autoPlay`,
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: videoAutoPlay,
        },
        {
          id: `currentTime`,
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          id: `duration`,
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: duration,
        },
        {
          id: `endTime`,
          key: 'endTime',
          type: CapiVariableTypes.STRING,
          value: endTime || '',
        },
        {
          id: `exposureInSeconds`,
          key: 'exposureInSeconds',
          type: CapiVariableTypes.NUMBER,
          value: currentTime,
        },
        {
          id: `exposureInPercentage`,
          key: 'exposureInPercentage',
          type: CapiVariableTypes.NUMBER,
          value: isNaN(exposureInPercentage) ? 0 : parseInt(exposureInPercentage.toString()),
        },
        {
          id: `hasCompleted`,
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: isVideoCompleted,
        },
        {
          id: `startTime`,
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: startTime || 0,
        },
        {
          id: `state`,
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: videoState,
        },
        {
          id: `totalSecondsWatched`,
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          id: `enableReplay`,
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
