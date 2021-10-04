/* eslint-disable react/prop-types */
import React, { ChangeEvent, CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import { SliderModel } from './schema';
import './Slider.scss';

const Slider: React.FC<PartComponentProps<SliderModel>> = (props) => {
  const [state, setState] = useState<unknown>([]);
  const [model, setModel] = useState<Partial<SliderModel>>({});
  const [ready, setReady] = useState<boolean>(false);

  const id: string = props.id;
  const [inputInnerWidth, setInputInnerWidth] = useState<number>(0);
  const [spanInnerWidth, setSpanInnerWidth] = useState<number>(0);

  const [sliderValue, setSliderValue] = useState(0);
  const [isSliderEnabled, setIsSliderEnabled] = useState(true);
  const [cssClass, setCssClass] = useState('');

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
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
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
    customCssClass,
    label,
    maximum = 1,
    minimum = 0,
    snapInterval,
    showDataTip,
    showValueLabels,
    showLabel,
    showTicks,
    invertScale,
  } = model;

  const styles: CSSProperties = {
    /* position: 'absolute',
    width: `${width}px`,
    top: `${y}px`,
    left: `${x}px`,
    height: `${height}px`,
    zIndex: z, */
    flexDirection: model.showLabel ? 'column' : 'row',
  };
  const inputStyles: CSSProperties = {
    width: '100%',
    height: `${height}px`,
    zIndex: z,
    direction: invertScale ? 'rtl' : 'ltr',
  };
  const divStyles: CSSProperties = {
    width: '100%',
    display: `flex`,
    flexDirection: 'row',
  };

  const inputWidth = inputInnerWidth;
  const thumbWidth = spanInnerWidth;
  const thumbHalfWidth = thumbWidth / 2;
  const thumbPosition =
    ((Number(sliderValue) - minimum) / (maximum - minimum)) *
    (inputWidth - thumbWidth + thumbHalfWidth);
  const thumbMargin = thumbHalfWidth * -1 + thumbHalfWidth / 2;

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

  const handleSliderChange = (e: ChangeEvent<HTMLInputElement>) => {
    const sliderVal = parseFloat(e.target.value);
    setSliderValue(sliderVal);
    saveState({ sliderVal, userModified: true });
  };
  const inputTargetRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (inputTargetRef && inputTargetRef.current) {
      setInputInnerWidth(inputTargetRef?.current?.offsetWidth);
    }
  });

  const divTargetRef = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    if (divTargetRef && divTargetRef.current) {
      setSpanInnerWidth(divTargetRef?.current?.offsetWidth);
    }
  });

  const internalId = `${id}__slider`;

  return ready ? (
    <div data-janus-type={tagName} style={styles} className={`slider`}>
      {showLabel && (
        <label className="input-label" htmlFor={internalId}>
          {label}
        </label>
      )}
      <div className="sliderInner">
        {showValueLabels && <label htmlFor={internalId}>{invertScale ? maximum : minimum}</label>}
        <div className="rangeWrap">
          <div style={divStyles}>
            {showDataTip && (
              <div className="rangeValue" id={`rangeV-${internalId}`}>
                <span
                  ref={divTargetRef}
                  id={`slider-thumb-${internalId}`}
                  style={{
                    left: `${invertScale ? undefined : thumbPosition}px`,
                    marginLeft: `${invertScale ? undefined : thumbMargin}px`,
                    right: `${invertScale ? thumbPosition : undefined}px`,
                    marginRight: `${invertScale ? thumbMargin : undefined}px`,
                  }}
                >
                  {sliderValue}
                </span>
              </div>
            )}
            <input
              ref={inputTargetRef}
              disabled={!isSliderEnabled}
              style={inputStyles}
              min={minimum}
              max={maximum}
              type={'range'}
              value={sliderValue}
              step={snapInterval}
              className={` slider `}
              id={internalId}
              onChange={handleSliderChange}
            />
          </div>
        </div>
        {showValueLabels && <label htmlFor={internalId}>{invertScale ? minimum : maximum}</label>}
      </div>
    </div>
  ) : null;
};

export const tagName = 'janus-slider';

export default Slider;
