/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { AuthorPartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const ImageAuthor: React.FC<AuthorPartComponentProps<ImageModel>> = (props) => {
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

  const { width, height, src, alt } = model;
  const imageStyles: CSSProperties = {
    width,
    height,
  };

  return ready ? <img draggable="false" alt={alt} src={src} style={imageStyles} /> : null;
};

export const tagName = 'janus-image';

export default ImageAuthor;
