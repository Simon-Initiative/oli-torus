/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { JanusAbsolutePositioned, JanusCustomCss, PartComponentProps } from '../types/parts';

interface ImageModel extends JanusAbsolutePositioned, JanusCustomCss {
  src: string;
  alt: string;
}

const ImageAuthor: React.FC<PartComponentProps<ImageModel>> = (props) => {
  const { model } = props;
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  useEffect(() => {
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const { x, y, z, width, height, src, alt, customCssClass } = model;
  const imageStyles: CSSProperties = {
    width,
    height,
  };

  return ready ? <img draggable="false" alt={alt} src={src} style={imageStyles} /> : null;
};

export const tagName = 'janus-image';

export default ImageAuthor;
