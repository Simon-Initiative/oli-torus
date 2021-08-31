import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { MultiLineTextModel } from './schema';

const MultiLineTextInputAuthor: React.FC<AuthorPartComponentProps<MultiLineTextModel>> = (
  props,
) => {
  const { model } = props;

  const { x, y, z, width } = model;
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
    <div style={styles}>
      <p>Multi-Line Text Input</p>
    </div>
  );
};

export const tagName = 'janus-multi-line-text';

export default MultiLineTextInputAuthor;
