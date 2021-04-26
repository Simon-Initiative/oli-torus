/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';

// TODO: fix typing
const Image: React.FC<any> = (props) => {
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

  const { x, y, z, width, height, src, alt, customCssClass } = model;
  const imageStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };
  useEffect(() => {
    // all activities *must* emit onReady
    // console.log('IMAGE ONE TIME', props.id);
    // eslint-disable-next-line
    props.onReady({ id: `${props.id}` });
  }, []);
  return (
    <img
      // eslint-disable-next-line
      data-janus-type={props.type}
      alt={alt}
      src={src}
      className={customCssClass}
      style={imageStyles}
    />
  );
};

export const tagName = 'janus-image';

// TODO: redo web component

export default Image;
