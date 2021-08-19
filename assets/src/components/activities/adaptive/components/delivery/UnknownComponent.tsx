/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';

// TODO: fix typing
const Unknown: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  const { x, y, z, width } = model;
  const styles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    // height,
    zIndex: z,
    backgroundColor: '#eee',
    overflow: 'hidden',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div
      // eslint-disable-next-line
      data-part_component-type={props.type}
      style={styles}
    >
      <p>Unknown Part Component Type:</p>
      <p>{props.type}</p>
    </div>
  );
};

export const tagName = 'unknown-component';

export default Unknown;
