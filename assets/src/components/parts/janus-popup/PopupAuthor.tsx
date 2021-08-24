import { PartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';

const PopupAuthor: React.FC<PartComponentProps<any>> = (props) => {
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
      <p>Popup</p>
    </div>
  );
};

export const tagName = 'janus-popup';

export default PopupAuthor;
