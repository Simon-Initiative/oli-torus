import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { McqModel } from './schema';

const McqAuthor: React.FC<AuthorPartComponentProps<McqModel>> = (props) => {
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
      <p>MCQ</p>
    </div>
  );
};

export const tagName = 'janus-mcq';

export default McqAuthor;
