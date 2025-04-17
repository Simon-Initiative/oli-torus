import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import './Slider-Text.scss';
import { SliderTextModel } from './schema';

const SliderTextAuthor: React.FC<AuthorPartComponentProps<SliderTextModel>> = (props) => {
  const { id, model } = props;
  const { showLabel, minimum, label, sliderOptionLabels } = model;

  const styles: CSSProperties = {
    width: '100%',
    flexDirection: showLabel ? 'column' : 'row',
  };
  const [sliderValue, _setSliderValue] = useState(0);
  const sliderRef = useRef<HTMLInputElement>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    _setSliderValue(Number(e.target.value));
  };

  const handleTickClick = (index: number) => {
    _setSliderValue(index);
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const internalId = `${id}__slider`;
  return (
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
            max={sliderOptionLabels.length - 1}
            step={1}
            value={sliderValue}
            onChange={handleChange}
            className="slider-track"
          />

          <div className="tick-container">
            {sliderOptionLabels.map((label, index) => (
              <div key={index} className="tick" onClick={() => handleTickClick(index)}>
                <div className="tick-mark" />
                <div className="tick-label">{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-text-slider';

export default SliderTextAuthor;
