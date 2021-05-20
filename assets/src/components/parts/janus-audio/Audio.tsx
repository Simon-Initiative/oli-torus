/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import React, { CSSProperties, useEffect, useState } from 'react';
import { CapiVariable } from '../types/parts';

// TODO: fix typing
const Audio: React.FC<any> = (props) => {
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
          id: `stage.${props.id}.hasStarted`,
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          id: `stage.${props.id}.currentTime`,
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: startTime,
        },
        {
          id: `stage.${props.id}.duration`,
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: '',
        },
        {
          id: `stage.${props.id}.hasCompleted`,
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          id: `stage.${props.id}.state`,
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: false,
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
    autoPlay,
    startTime,
    endTime,
    enableReplay,
    subtitles,
  } = model;
  const audioStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
    outline: 'none',
    filter: 'sepia(20%) saturate(70%) grayscale(1) contrast(99%) invert(12%)',
  };
  const onReady = props.onReady;
  const [showControls, setShowControls] = useState(true);
  const [classes, setClasses] = useState<any>(customCssClass);
  let finalSrc = src;
  if (startTime && startTime >= 0) {
    finalSrc = `${finalSrc}#t=${startTime || 0}`;
    if (endTime && endTime >= 0) {
      finalSrc = `${finalSrc},${endTime}`;
    }
  }
  const saveState = ({
    isAudioPlayerStarted,
    currentTime,
    duration,
    isAudioCompleted,
    audioState,
  }: {
    isAudioPlayerStarted: boolean;
    currentTime: any;
    duration: any;
    isAudioCompleted: boolean;
    audioState: string;
  }) => {
    const currentVideoTime = parseFloat(currentTime || 0);
    const audioDuration = parseFloat(duration || 0);
    const exposureInPercentage = (currentVideoTime / audioDuration) * 100;
    props.onSave({
      activityId: `${props.id}`,
      partResponses: [
        {
          id: `stage.${props.id}.hasStarted`,
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: isAudioPlayerStarted,
        },
        {
          id: `stage.${props.id}.autoPlay`,
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: autoPlay,
        },
        {
          id: `stage.${props.id}.currentTime`,
          key: 'currentTime',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          id: `stage.${props.id}.duration`,
          key: 'duration',
          type: CapiVariableTypes.STRING,
          value: duration,
        },
        {
          id: `stage.${props.id}.endTime`,
          key: 'endTime',
          type: CapiVariableTypes.STRING,
          value: endTime || '',
        },
        {
          id: `stage.${props.id}.exposureInSeconds`,
          key: 'exposureInSeconds',
          type: CapiVariableTypes.NUMBER,
          value: currentTime,
        },
        {
          id: `stage.${props.id}.exposureInPercentage`,
          key: 'exposureInPercentage',
          type: CapiVariableTypes.NUMBER,
          value: isNaN(exposureInPercentage) ? 0 : parseInt(exposureInPercentage.toString()),
        },
        {
          id: `stage.${props.id}.hasCompleted`,
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: isAudioCompleted,
        },
        {
          id: `stage.${props.id}.startTime`,
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: startTime || 0,
        },
        {
          id: `stage.${props.id}.state`,
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: audioState,
        },
        {
          id: `stage.${props.id}.totalSecondsWatched`,
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
          id: `stage.${props.id}.customCssClass`,
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: customCssClass,
        },
      ],
    });
  };

  let isAudioStarted = false;
  // handle the Audio player start
  const handleAudioEnd = () => {
    if (!enableReplay) {
      setShowControls(false);
    }
  };
  const handleAudioPlay = (data: any) => {
    if (isAudioStarted) return;
    //Need this otherwise, save state will called on every second
    isAudioStarted = true;
    saveState({
      isAudioPlayerStarted: true,
      currentTime: data.target.currentTime,
      duration: data.target.duration,
      isAudioCompleted: false,
      audioState: 'playing',
    });
  };

  const handleAudioPause = (data: any) => {
    saveState({
      isAudioPlayerStarted: true,
      currentTime: data.target.currentTime,
      duration: data.target.duration,
      isAudioCompleted: false,
      audioState: 'paused',
    });
  };

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const handleStateChange = (data: CapiVariable[]) => {
    // this runs every time state is updated from *any* source
    // the global variable state
    const interested = data.filter((stateVar) => stateVar.id.indexOf(`stage.${props.id}.`) === 0);

    interested.forEach((stateVar) => {
      switch (stateVar.key) {
        case 'customCssClass':
          setClasses(String(stateVar.value));
          break;
      }
    });
  };
  return (
    <audio
      data-janus-type={props.type}
      className={classes}
      style={audioStyles}
      autoPlay={autoPlay}
      controls={showControls}
      controlsList="nodownload"
      onEnded={handleAudioEnd}
      onPlay={handleAudioPlay}
      onPause={handleAudioPause}
    >
      <source src={finalSrc} />

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
    </audio>
  );
};

export const tagName = 'janus-audio';

export default Audio;
