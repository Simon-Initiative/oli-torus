/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { parseBoolean } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

// TODO: fix typing
const Slider: React.FC<any> = (props) => {
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
          id: `stage.${id}.value`,
          key: `value`,
          type: CapiVariableTypes.NUMBER,
          value: 0,
        },
        {
          id: `stage.${id}.userModified`,
          key: `userModified`,
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          id: `stage.${id}.enabled`,
          key: `enabled`,
          type: CapiVariableTypes.BOOLEAN,
          value: isSliderEnabled,
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

  const [sliderValue, setSliderValue] = useState(value ? value : minimum); // if value is undefined, set default to minimum value;
  const [isSliderEnabled, setIsSliderEnabled] = useState(true);

  const inputWidth: any = document.getElementById(`${id}`)?.getBoundingClientRect().width;
  const thumbWidth: any = document.getElementById(`slider-thumb-${id}`)?.getBoundingClientRect()
    .width;
  const thumbHalfWidth: any = thumbWidth / 2;
  const thumbPosition =
    ((sliderValue - minimum) / (maximum - minimum)) * (inputWidth - thumbWidth + thumbHalfWidth);
  const thumbMargin = thumbHalfWidth * -1 + thumbHalfWidth / 2;

  const saveState = ({ sliderVal, userModified }: { sliderVal: number; userModified: boolean }) => {
    props.onSave({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.value`,
          key: `value`,
          type: CapiVariableTypes.NUMBER,
          value: sliderVal,
        },
        {
          id: `stage.${id}.userModified`,
          key: `userModified`,
          type: CapiVariableTypes.BOOLEAN,
          value: userModified,
        },
        {
          id: `stage.${id}.enabled`,
          key: `enabled`,
          type: CapiVariableTypes.BOOLEAN,
          value: isSliderEnabled,
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

  return (
    <div data-janus-type={props.type} style={styles} className={'slider'}>
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
  );
};

export const tagName = 'janus-slider';

export default Slider;
