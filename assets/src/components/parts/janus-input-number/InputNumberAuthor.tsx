import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { InputNumberModel } from './schema';

const InputNumberAuthor: React.FC<AuthorPartComponentProps<InputNumberModel>> = (props) => {
  const { id, model } = props;

  const {
    width,
    minValue,
    maxValue,
    unitsLabel,
    label,
    showLabel,
    showIncrementArrows,
    prompt = '',
  } = model;

  const styles: CSSProperties = {
    width,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div className={`number-input`} style={styles}>
      {showLabel && (
        <React.Fragment>
          <label htmlFor={`${id}-number-input`} className="inputNumberLabel">
            {label.length > 0 ? label : ''}
          </label>
          <br />
        </React.Fragment>
      )}
      <input
        name="janus-input-number"
        id={`${id}-number-input`}
        type="number"
        placeholder={prompt}
        min={minValue}
        max={maxValue}
        disabled={true}
        style={{ width: '100%' }}
        className={`${showIncrementArrows ? '' : 'hideIncrementArrows'}`}
      />
      {unitsLabel && <span className="unitsLabel">{unitsLabel}</span>}
    </div>
  );
};

export const tagName = 'janus-input-number';

export default InputNumberAuthor;
