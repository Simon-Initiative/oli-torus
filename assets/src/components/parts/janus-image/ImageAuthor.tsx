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

  const { width, height, src, alt, defaultWidth, defaultHeight, defaultSrc } = model;
  const imageStyles: CSSProperties = {
    width,
    height,
  };
  const imageContainerRef = useRef<HTMLImageElement>(null);
  const manipulateImageSize = () => {
    if (!imageContainerRef?.current) {
      return;
    }
    // if author has not resized the image and the src is not the default src then only we adjust the aspect ratio
    if (defaultWidth === width && defaultHeight === height && defaultSrc !== src) {
      const naturalWidth = imageContainerRef.current.naturalWidth;
      const naturalHeight = imageContainerRef.current.naturalHeight;
      const ratioWidth = naturalWidth / imageContainerRef.current.width;
      const ratioHeight = naturalHeight / imageContainerRef.current.height;
      let newAdjustedHeight = imageContainerRef.current.height;
      let newAdjustedWidth = imageContainerRef.current.width;
      if (ratioWidth > ratioHeight) {
        newAdjustedHeight = parseInt(Number(naturalHeight / ratioWidth).toFixed());
      } else {
        newAdjustedWidth = parseInt(Number(naturalWidth / ratioHeight).toFixed());
      }
      const modelClone = clone(model);
      modelClone.height = newAdjustedHeight;
      modelClone.width = newAdjustedWidth;
      if (newAdjustedHeight != height || newAdjustedWidth != width) {
        //we need to save the new width and height of the image so that the custom property is updated with adjusted values
        onSaveConfigure({ id, snapshot: modelClone });
      }
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
