/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBoolean } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

// TODO: fix typing
const Slider: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);

  const id: string = props.id;

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

  const {
    x,
    y,
    z,
    width,
    height,
    src,
    alt,
    customCssClass,
    label,
    maximum,
    minimum,
    snapInterval,
    showDataTip,
    showValueLabels,
    showThumbByDefault,
    showLabel,
    showTicks,
    invertScale,
    value,
  } = model;

  const styles: CSSProperties = {
    position: 'absolute',
    width: `${width}px`,
    top: `${y}px`,
    left: `${x}px`,
    height: `${height}px`,
    zIndex: z,
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

  const inputWidth: any = document.getElementById(`${id}`)?.getBoundingClientRect().width;
  const thumbWidth: any = document.getElementById(`slider-thumb-${id}`)?.getBoundingClientRect()
    .width;
  const thumbHalfWidth: any = thumbWidth / 2;
  const thumbPosition =
    ((sliderValue - minimum) / (maximum - minimum)) * (inputWidth - thumbWidth + thumbHalfWidth);
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

  const handleSliderChange = (e: any) => {
    setSliderValue(e.target.value);
    saveState({ sliderVal: e.target.value, userModified: true });
  };

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const handleStateChange = (stateData: CapiVariable[]) => {
    const interested = stateData.filter(
      (stateVar: any) => stateVar.id.indexOf(`stage.${id}.`) >= 0,
    );
    if (interested?.length) {
      interested.forEach((stateVar: any) => {
        if (stateVar.key === 'enabled') {
          setIsSliderEnabled(parseBoolean(stateVar.value));
        }
        if (stateVar.key === 'value') {
          const num = parseInt(stateVar.value as string, 10);
          setSliderValue(num);
        }
      });
    }
  };

  return ready ? (
    <div data-part-component-type={props.type} style={styles} className={`slider ${cssClass}`}>
      <div className="sliderInner">
        {showValueLabels && <label htmlFor={id}>{invertScale ? maximum : minimum}</label>}
        <div className="rangeWrap">
          <div style={divStyles}>
            {showDataTip && (
              <div className="rangeValue" id={`rangeV-${id}`}>
                <span
                  id={`slider-thumb-${id}`}
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
              disabled={!isSliderEnabled}
              style={inputStyles}
              min={minimum}
              max={maximum}
              type={'range'}
              value={sliderValue}
              step={snapInterval}
              className={` slider ` + customCssClass}
              id={id}
              onChange={handleSliderChange}
            />
          </div>
        </div>
        {showValueLabels && <label htmlFor={id}>{invertScale ? minimum : maximum}</label>}
      </div>
      {showLabel && (
        <label className="input-label" htmlFor={id}>
          {label}
        </label>
      )}
    </div>
  ) : null;
};

export const tagName = 'janus-slider';

export default Slider;
