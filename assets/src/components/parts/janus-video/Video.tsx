/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import YouTube from 'react-youtube';

// TODO: fix typing
const Video: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [videoIsPlayerStarted, setVideoIsPlayerStarted] = useState(false);
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
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const handleVideoEnd = (data: any) => {
    setVideoIsPlayerStarted(true);
    // saveState({
    //     isVideoPlayerStarted: true,
    //     currentTime: isYoutubeSrc
    //         ? data.target.getCurrentTime()
    //         : data.target.currentTime,
    //     duration: isYoutubeSrc
    //         ? data.target.getDuration()
    //         : data.target.duration,
    //     isVideoCompleted: true,
    //     videoState: 'completed',
    // });
    // if (triggerCheck) {
    //     onSubmitActivity({ Id: `${id}`, partResponses: [] });
    // }
  };

  let isVideoStarted = false;
  const handleVideoPlay = () => {
    if (isVideoStarted) return;
    isVideoStarted = true;
    setVideoIsPlayerStarted(true);
    // saveState({
    //     isVideoPlayerStarted: true,
    //     currentTime: isYoutubeSrc
    //         ? data.target.getCurrentTime()
    //         : data.target.currentTime,
    //     duration: isYoutubeSrc
    //         ? data.target.getDuration()
    //         : data.target.duration,
    //     isVideoCompleted: false,
    //     videoState: 'playing',
    // });
  };

  const handleVideoPause = () => {
    setVideoIsPlayerStarted(true);
    // saveState({
    //     isVideoPlayerStarted: true,
    //     currentTime: isYoutubeSrc
    //         ? data.target.getCurrentTime()
    //         : data.target.currentTime,
    //     duration: isYoutubeSrc
    //         ? data.target.getDuration()
    //         : data.target.duration,
    //     isVideoCompleted: false,
    //     videoState: 'paused',
    // });
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
