import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { InputTextModel } from './schema';

const InputTextAuthor: React.FC<AuthorPartComponentProps<InputTextModel>> = (props) => {
  const { id, model } = props;

  const { x, y, z, width, height, showLabel, label, prompt, fontSize } = model;
  const styles: CSSProperties = {
    width: '100%',
    // height // TODO: only if the delivery component supports it
    zIndex: z,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div className={`short-text-input`} style={styles}>
      <label htmlFor={`${id}-short-text-input`}>
        {showLabel && label ? label : <span>&nbsp;</span>}
      </label>
      <input
        name="janus-input-text"
        id={`${id}-short-text-input`}
        type="text"
        placeholder={prompt}
        disabled={true}
        style={{ width: '100%', fontSize }}
      />
    </div>
  );
};

export const tagName = 'janus-input-text';

export default InputTextAuthor;
