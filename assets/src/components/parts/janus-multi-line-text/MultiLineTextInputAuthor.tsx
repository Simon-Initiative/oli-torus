import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { MultiLineTextModel } from './schema';

const MultiLineTextInputAuthor: React.FC<AuthorPartComponentProps<MultiLineTextModel>> = (
  props,
) => {
  const { id, model } = props;

  const {
    label,
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    prompt,
    showLabel,
    initValue,
    fontSize,
    showCharacterCount,
  } = model;
  const wrapperStyles: CSSProperties = {
    width,
  };
  const inputStyles: CSSProperties = {
    width,
    height,
    resize: 'none',
    fontSize,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div data-janus-type={tagName} className={`long-text-input`} style={wrapperStyles}>
      <label
        htmlFor={`${id}-input`}
        style={{
          display: showLabel ? 'inline-block' : 'none',
        }}
      >
        {label}
      </label>
      <textarea
        name={`name-${id}`}
        id={`${id}-input`}
        style={inputStyles}
        placeholder={prompt}
        value={initValue || ''}
        disabled={true}
      />
      <div
        title="Number of characters"
        className="characterCounter"
        style={{
          padding: '0px',
          color: 'rgba(0,0,0,0.6)',
          display: showCharacterCount ? 'block' : 'none',
          width: '100%',
          fontSize: '12px',
          fontFamily: 'Arial',
          textAlign: 'right',
        }}
      >
        <span
          className={`span_${id}`}
          style={{
            padding: '0px',
            fontFamily: 'Arial',
          }}
        >
          {0}
        </span>
      </div>
    </div>
  );
};

export const tagName = 'janus-multi-line-text';

export default MultiLineTextInputAuthor;
