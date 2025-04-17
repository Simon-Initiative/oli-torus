/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import './Slider-Text.scss';
import { SliderTextModel } from './schema';

const SliderText: React.FC<PartComponentProps<SliderTextModel>> = (props) => {
  const [_state, setState] = useState<unknown>([]);
  const [model, setModel] = useState<Partial<SliderTextModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const id: string = props.id;
  const [sliderValue, setSliderValue] = useState(0);
  const [isSliderEnabled, setIsSliderEnabled] = useState(true);
  const [_cssClass, setCssClass] = useState('');
  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : isSliderEnabled;
    setIsSliderEnabled(dEnabled);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    const dMin = pModel.minimum || 0;
    const dValue = pModel.value || dMin;
    setSliderValue(dValue);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
        {
          key: 'value',
          type: CapiVariableTypes.NUMBER,
          value: dValue,
        },
        {
          key: 'userModified',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setIsSliderEnabled(sEnabled);
    }
    const sValue = currentStateSnapshot[`stage.${id}.value`];
    if (sValue !== undefined) {
      setSliderValue(sValue);
    }
    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }
    if (initResult.context.mode === contexts.REVIEW) {
      setIsSliderEnabled(false);
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
        /* console.log(`${notificationType.toString()} notification handled [Slider]`, payload); */
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
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setIsSliderEnabled(sEnabled);
              }
              const sValue = changes[`stage.${id}.value`];
              if (sValue !== undefined) {
                setSliderValue(sValue);
              }
              const sCssClass = changes[`stage.${id}.customCssClass`];
              if (sCssClass !== undefined) {
                setCssClass(sCssClass);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setIsSliderEnabled(sEnabled);
              }
              const sValue = changes[`stage.${id}.value`];
              if (sValue !== undefined) {
                setSliderValue(sValue);
              }
              const sCssClass = changes[`stage.${id}.customCssClass`];
              if (sCssClass !== undefined) {
                setCssClass(sCssClass);
              }
              if (payload.mode === contexts.REVIEW) {
                setIsSliderEnabled(false);
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

  const { width, height, label, minimum = 0, showLabel, sliderOptionLabels } = model;

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
  const styles: CSSProperties = {
    width: '100%',
    flexDirection: showLabel ? 'column' : 'row',
  };

  const saveState = ({ sliderVal, userModified }: { sliderVal: number; userModified: boolean }) => {
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: `value`,
          type: CapiVariableTypes.NUMBER,
          value: sliderVal,
        },
        {
          key: `userModified`,
          type: CapiVariableTypes.BOOLEAN,
          value: userModified,
        },
      ],
    });
  };

  const sliderRef = useRef<HTMLInputElement>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const sliderValue = Number(e.target.value);
    setSliderValue(sliderValue);
    saveState({ sliderVal: sliderValue, userModified: true });
  };

  const handleTickClick = (index: number) => {
    saveState({ sliderVal: index, userModified: true });
    setSliderValue(index);
  };
  const internalId = `${id}__slider`;

  return ready ? (
    <div data-janus-type={tagName} style={styles} className={`slider`}>
      {showLabel && (
        <label className="input-label" htmlFor={internalId}>
          {label}
        </label>
      )}
      <div className="sliderInner" style={!showLabel ? { width: '100%' } : {}}>
        <div className="slider-wrapper">
          <input
            ref={sliderRef}
            type="range"
            id={internalId}
            min={minimum}
            max={sliderOptionLabels?.length ? sliderOptionLabels?.length - 1 : 3}
            step={1}
            value={sliderValue}
            onChange={handleChange}
            className="slider-track"
          />

          <div className="tick-container">
            {sliderOptionLabels?.map((label, index) => (
              <div key={index} className="tick" onClick={() => handleTickClick(index)}>
                <div className="tick-mark" />
                <div className="tick-label">{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  ) : null;
};

export const tagName = 'janus-text-slider';

export default SliderText;
