/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import { clone } from 'utils/common';
import { AuthorPartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const ImageAuthor: React.FC<AuthorPartComponentProps<ImageModel>> = (props) => {
  const { model, onSaveConfigure } = props;
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
  const imageContainerRef = useRef<HTMLImageElement>(null);
    if (!imageContainerRef?.current) {
      return;
    const naturalWidth = imageContainerRef.current.naturalWidth;
    const naturalHeight = imageContainerRef.current.naturalHeight;
    const ratioWidth = naturalWidth / imageContainerRef.current.width;
    const ratioHeight = naturalHeight / imageContainerRef.current.height;
    let newAdjustedHeight = imageContainerRef.current.height;
    let newAdjustedWidth = imageContainerRef.current.width;
    if (ratioWidth > ratioHeight) {
      const newHeight = Number(naturalHeight / ratioWidth).toFixed();
      newAdjustedHeight = parseInt(newHeight);
    } else {
      const newWidth = Number(naturalWidth / ratioHeight).toFixed();
      newAdjustedWidth = parseInt(newWidth);
    }
    const modelClone = clone(model);
    modelClone.height = newAdjustedHeight;
    modelClone.width = newAdjustedWidth;
    if (newAdjustedHeight != height || newAdjustedWidth != width) {
      //console.log('I AM SETTING NOW ->', { newAdjustedHeight, newAdjustedWidth, model });
      onSaveConfigure({ id, snapshot: modelClone });
    }
  };
  return ready ? (
    <img
      ref={imageContainerRef}
      onLoad={manipulateImageSize}
      draggable="false"
      alt={alt}
      src={src}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';

export default ImageAuthor;
