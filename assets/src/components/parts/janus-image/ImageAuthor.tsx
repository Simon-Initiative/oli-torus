import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import debounce from 'lodash/debounce';
import { clone } from 'utils/common';
import { AuthorPartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

// 🔹 Module-level variable persists across re-renders and re-mounts
let lastSavedSize: { width?: number; height?: number } = {};
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

  const { width, height, src, alt, defaultSrc, lockAspectRatio } = model;
  const imageStyles: CSSProperties = {
    width,
    height,
  };

  const debounceWaitTime = 1000;
  const debounceImageAdjust = useCallback(
    debounce((updatedModel: any) => {
      manipulateImageSize(updatedModel, true);
    }, debounceWaitTime),
    [],
  );

  useEffect(() => {
    if (src?.length && src !== defaultSrc && lockAspectRatio) {
      debounceImageAdjust(model);
    }
  }, [model, lockAspectRatio]);
  const imageContainerRef = useRef<HTMLImageElement>(null);
  const manipulateImageSize = (updatedModel: ImageModel, isfromDebaunce: boolean) => {
    if (!imageContainerRef?.current || !isfromDebaunce) {
      return;
    }
    const naturalWidth = imageContainerRef.current.naturalWidth;
    const naturalHeight = imageContainerRef.current.naturalHeight;

    const currentWidth = imageContainerRef.current.width;
    const currentHeight = imageContainerRef.current.height;
    if (naturalWidth <= 0 || naturalHeight <= 0 || currentWidth <= 0 || currentHeight <= 0) {
      return;
    }
    const ratioWidth = naturalWidth / currentWidth;
    const ratioHeight = naturalHeight / currentHeight;
    if (ratioWidth == ratioHeight) {
      return;
    }
    let newAdjustedHeight = imageContainerRef.current.height;
    let newAdjustedWidth = imageContainerRef.current.width;
    if (ratioWidth > ratioHeight) {
      newAdjustedHeight = parseInt(Number(naturalHeight / ratioWidth).toFixed());
    } else {
      newAdjustedWidth = parseInt(Number(naturalWidth / ratioHeight).toFixed());
    }
    const modelClone = clone(updatedModel);
    modelClone.height = newAdjustedHeight;
    modelClone.width = newAdjustedWidth;
    if (
      (newAdjustedHeight != updatedModel.height || newAdjustedWidth != updatedModel.width) &&
      newAdjustedWidth !== lastSavedSize.width &&
      newAdjustedHeight !== lastSavedSize.height
    ) {
      // Update module-level tracker
      lastSavedSize = { width: newAdjustedWidth, height: newAdjustedHeight };
      //we need to save the new width and height of the image so that the custom property is updated with adjusted values
      onSaveConfigure({ id, snapshot: modelClone });
    }
  };
  return ready ? (
    <img
      ref={imageContainerRef}
      onLoad={() => {
        lockAspectRatio && manipulateImageSize(model, false);
      }}
      draggable="false"
      alt={alt}
      src={src}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';
export default ImageAuthor;
