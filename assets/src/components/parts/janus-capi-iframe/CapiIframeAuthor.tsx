import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { CapiIframeModel } from './schema';

const CapiIframeAuthor: React.FC<AuthorPartComponentProps<CapiIframeModel>> = (props) => {
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
      <p>CAPI Iframe</p>
    </div>
  );
};

export const tagName = 'janus-capi-iframe';

export default CapiIframeAuthor;
