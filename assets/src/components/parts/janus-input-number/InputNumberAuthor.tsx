import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { InputNumberModel } from './schema';

const InputNumberAuthor: React.FC<AuthorPartComponentProps<InputNumberModel>> = (props) => {
  const { id, model } = props;

  const { x, y, z, width, height, showLabel, label, prompt, showIncrementArrows } = model;
  const styles: CSSProperties = {
    width,
    zIndex: z,
    backgroundColor: 'magenta',
    overflow: 'hidden',
    fontWeight: 'bold',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div className={`number-input`} style={styles}>
      <label htmlFor={`${id}-number-input`}>
        {showLabel && label ? label : <span>&nbsp;</span>}
      </label>
      <input
        name="janus-input-number"
        id={`${id}-number-input`}
        type="number"
        placeholder={prompt}
        disabled={true}
        style={{ width: '100%' }}
        className={`${showIncrementArrows ? '' : 'hideIncrementArrows'}`}
      />
    </div>
  );
};

export const tagName = 'janus-input-number';

export default InputNumberAuthor;
