import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import { AudioModel } from './schema';

const Audio: React.FC<PartComponentProps<AudioModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  const [showControls, setShowControls] = useState(true);
  const [classes, setClasses] = useState<any>('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dCssClass = pModel.customCssClass || classes;
    setClasses(dCssClass);

    const dShowControls =
      typeof pModel.showControls === 'boolean' ? pModel.showControls : showControls;
    setShowControls(dShowControls);

    const dStartTime = pModel.startTime || 0;
    const dEndTime = pModel.endTime || '';

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
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
          key: 'hasCompleted',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: 'notStarted',
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;

    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setClasses(sCssClass);
    }

    const sAutoPlay = currentStateSnapshot[`stage.${id}.autoPlay`];
    if (sAutoPlay !== undefined) {
      setAudioAutoPlay(sAutoPlay);
    }

    const sEnableReplay = currentStateSnapshot[`stage.${id}.enableReplay`];
    if (sEnableReplay !== undefined) {
      setAudioEnableReplay(sEnableReplay);
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
        /* console.log(`${notificationType.toString()} notification handled [Audio]`, payload); */
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
              const sCustomCssClass = changes[`stage.${id}.customCssClass`];
              if (sCustomCssClass !== undefined) {
                setClasses(String(sCustomCssClass));
              }
              const sAutoPlay = changes[`stage.${id}.autoPlay`];
              if (sAutoPlay !== undefined) {
                setAudioAutoPlay(sAutoPlay);
              }

              const sEnableReplay = changes[`stage.${id}.enableReplay`];
              if (sEnableReplay !== undefined) {
                setAudioEnableReplay(sEnableReplay);
              }

              const sHasStarted = changes[`stage.${id}.hasStarted`];
              if (sHasStarted !== undefined) {
                setAudioIsPlayerStarted(sHasStarted);
                props.onSave({
                  id,
                  responses: [
                    {
                      key: 'hasCompleted',
                      type: CapiVariableTypes.NUMBER,
                      value: parseBool(sHasStarted),
                    },
                  ],
                });
              }

              const sHasCompleted = changes[`stage.${id}.hasCompleted`];
              if (sHasCompleted !== undefined) {
                setAudioIsCompleted(sHasCompleted);
                props.onSave({
                  id,
                  responses: [
                    {
                      key: 'hasCompleted',
                      type: CapiVariableTypes.NUMBER,
                      value: parseBool(sHasCompleted),
                    },
                  ],
                });
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
  const [audioIsPlayerStarted, setAudioIsPlayerStarted] = useState(false);
  const [audioIsCompleted, setAudioIsCompleted] = useState(false);
  const [audioAutoPlay, setAudioAutoPlay] = useState(autoPlay || false);
  const [audioEnableReplay, setAudioEnableReplay] = useState(enableReplay || true);
  const audioStyles: CSSProperties = {
    /* position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z, */
    width,
    outline: 'none',
    filter: 'sepia(20%) saturate(70%) grayscale(1) contrast(99%) invert(12%)',
  };

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
      id: `${props.id}`,
      responses: [
        {
          key: 'hasStarted',
          type: CapiVariableTypes.BOOLEAN,
          value: isAudioPlayerStarted,
        },
        {
          key: 'autoPlay',
          type: CapiVariableTypes.BOOLEAN,
          value: autoPlay,
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
          value: isAudioCompleted,
        },
        {
          key: 'startTime',
          type: CapiVariableTypes.STRING,
          value: startTime || 0,
        },
        {
          key: 'state',
          type: CapiVariableTypes.STRING,
          value: audioState,
        },
        {
          key: 'totalSecondsWatched',
          type: CapiVariableTypes.STRING,
          value: currentTime,
        },
        {
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

  return ready ? (
    <audio
      data-janus-type={tagName}
      style={audioStyles}
      autoPlay={audioAutoPlay}
      loop={audioEnableReplay}
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
  ) : null;
};

export const tagName = 'janus-audio';

export default Audio;
