import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { clone } from 'utils/common';
import './Slider.scss';
import { SliderModel } from './schema';

const SliderAuthor: React.FC<AuthorPartComponentProps<SliderModel>> = (props) => {
  const { id, model, onSaveConfigure } = props;

  const {
    z,
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
    width: '100%',
    flexDirection: showLabel ? 'column' : 'row',
  };
  const inputStyles: CSSProperties = {
    width: '100%',
    height: `3px`,
    zIndex: z,
    direction: invertScale ? 'rtl' : 'ltr',
  };
  const divStyles: CSSProperties = {
    width: '100%',
    display: `flex`,
    flexDirection: 'row',
    alignItems: 'center',
  };

  const [inputInnerWidth, setInputInnerWidth] = useState<number>(0);
  const [spanInnerWidth, setSpanInnerWidth] = useState<number>(0);

  const [sliderValue, _setSliderValue] = useState(0);

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const inputWidth = inputInnerWidth;
  const thumbWidth = spanInnerWidth;
  const thumbHalfWidth = thumbWidth / 2;
  const thumbPosition =
    ((Number(sliderValue) - minimum) / (maximum - minimum)) *
    (inputWidth - thumbWidth + thumbHalfWidth);
  const thumbMargin = thumbHalfWidth * -1 + thumbHalfWidth / 2;

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
  const getTickOptions = () => {
    if (snapInterval) {
      const options = [];
      const numberOfTicks = (maximum - minimum) / snapInterval;
      const numberOfTricksThreshold = 100;
      if (numberOfTicks > numberOfTricksThreshold) {
        const modelClone = clone(model);
        const snapIntervalThreshold = (maximum - minimum) / numberOfTricksThreshold;
        // As per the requirement, Users cannot enter a value that divides the slider into more than 100 equal sections.
        // if it goes beyond that, we need to calculate the snapIntervalThreshold between the min and max values
        // and set the interval
        modelClone.snapInterval = +snapIntervalThreshold.toFixed(2);
        //we need to save the snapInterval so that the custom property is updated with adjusted values
        onSaveConfigure({ id, snapshot: modelClone });
        return;
      }
      for (let i = 0; i <= numberOfTicks; i++) {
        options.push(<option value={i * snapInterval}></option>);
      }
      return options;
    }
  };
  const internalId = `${id}__slider`;

  return (
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
              disabled={false}
              style={inputStyles}
              min={minimum}
              max={maximum}
              type={'range'}
              value={sliderValue}
              step={snapInterval}
              id={internalId}
              list={showTicks ? `datalist${internalId}` : ''}
            />
            {showTicks && (
              <datalist style={{ display: 'none' }} id={`datalist${internalId}`}>
                {getTickOptions()}
              </datalist>
            )}
          </div>
        </div>
        {showValueLabels && <label htmlFor={internalId}>{invertScale ? minimum : maximum}</label>}
      </div>
    </div>
  );
};

export const tagName = 'janus-slider';

export default SliderAuthor;
