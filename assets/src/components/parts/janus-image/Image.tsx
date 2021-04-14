import React, { CSSProperties, useEffect } from "react";

// TODO: fix typing
const Image: React.FC<any> = (props) => {
  const { x, y, z, width, height, src, alt, customCssClass } = props.model;
  const imageStyles: CSSProperties = {
    position: "absolute",
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };
  useEffect(() => {
    // all activities *must* emit onReady
    // console.log('IMAGE ONE TIME', props.id);

    props.onReady({ id: `${props.id}` });
  }, []);
  return (
    <img
      data-janus-type={props.type}
      alt={alt}
      src={src}
      className={customCssClass}
      style={imageStyles}
    />
  );
};

export const tagName = "janus-image";

// TODO: redo web component

export default Image;
