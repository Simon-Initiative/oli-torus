/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';

// TODO: fix typing
const Audio: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});

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

  let finalSrc = src;
  // if (startTime && startTime >= 0) {
  //     finalSrc = `${finalSrc}#t=${startTime || 0}`;
  //     if (endTime && endTime >= 0) {
  //         finalSrc = `${finalSrc},${endTime}`;
  //     }
  // }

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
    // saveState({
    //     isAudioPlayerStarted: true,
    //     currentTime: data.target.currentTime,
    //     duration: data.target.duration,
    //     isAudioCompleted: false,
    //     audioState: 'playing',
    // });
  };

  const handleAudioPause = (data: any) => {
    // saveState({
    //     isAudioPlayerStarted: true,
    //     currentTime: data.target.currentTime,
    //     duration: data.target.duration,
    //     isAudioCompleted: false,
    //     audioState: 'paused',
    // });
  };
  useEffect(() => {
    onReady({
      Id: props.id,
      partResponses: [],
    });
  }, []);

  return (
    <audio
      data-janus-type={props.type}
      className={customCssClass}
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
