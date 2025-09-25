import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import debounce from 'lodash/debounce';
import { clone } from 'utils/common';
import { AuthorPartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const ImageAuthor: React.FC<AuthorPartComponentProps<ImageModel>> = (props) => {
  const { model, onSaveConfigure, id, onReady } = props;
  const { width, height, alt, imageSrc, src, defaultSrc, lockAspectRatio } = model;
  const [ready, setReady] = useState<boolean>(false);
  const [imgSrc, setImgSrc] = useState<string>('');
  const imageContainerRef = useRef<HTMLImageElement>(null);

  const debounceImageAdjust = useRef(
    debounce((modelToUpdate: ImageModel) => {
      adjustImageSize(modelToUpdate);
    }, 1000),
  ).current;

  // === useRef guards to prevent duplicate syncs ===
  const lastSyncedImageSrcRef = useRef<string | null>(null);

  useEffect(() => {
    onReady?.({ id, responses: [] });
    setReady(true);
  }, [id, onReady]);

  const preferredSrc = imageSrc && imageSrc !== defaultSrc ? imageSrc : src;

  useEffect(() => {
    if (!model) return;

    setImgSrc(preferredSrc);

    const modelClone = clone(model);

    const srcNeedsUpdate =
      imageSrc && (!src || src !== imageSrc) && imageSrc !== lastSyncedImageSrcRef.current;
    const imageSrcIsDefault = imageSrc === defaultSrc;
    const srcChanged = src && src !== defaultSrc && src !== imageSrc;

    // ✅ Case 1 & 2: Sync src from imageSrc (panel wins)
    if (srcNeedsUpdate) {
      modelClone.src = imageSrc;
      console.log('Syncing src from imageSrc');
      console.log({ imageSrc, modelCloneSrc: modelClone.src });
      lastSyncedImageSrcRef.current = imageSrc;
      onSaveConfigure({ id, snapshot: modelClone });
    }

    // ✅ Case 3: Sync imageSrc from src (when imageSrc is default and src changed)
    else if (imageSrcIsDefault && srcChanged) {
      console.log('Syncing imageSrc from src');
      modelClone.imageSrc = src;
      onSaveConfigure({ id, snapshot: modelClone });
    }

    // 🔁 Debounced aspect ratio fix
    if (preferredSrc && preferredSrc !== defaultSrc && lockAspectRatio) {
      debounceImageAdjust(modelClone);
    }
  }, [preferredSrc, imageSrc, src, defaultSrc, lockAspectRatio]);

  const adjustImageSize = useCallback(
    (updatedModel: ImageModel) => {
      const imgEl = imageContainerRef.current;
      if (!imgEl) return;

      const { naturalWidth, naturalHeight, width: currentWidth, height: currentHeight } = imgEl;

      const updatedWidth = updatedModel?.width || 0;

      if (
        naturalWidth <= 0 ||
        naturalHeight <= 0 ||
        currentWidth <= 0 ||
        currentHeight <= 0 ||
        updatedWidth <= 0
      )
        return;

      const ratioWidth = naturalWidth / currentWidth;
      const ratioHeight = naturalHeight / currentHeight;

      if (ratioWidth === ratioHeight) return;

      let newWidth = currentWidth;
      let newHeight = currentHeight;

      if (ratioWidth > ratioHeight) {
        newHeight = Math.round(naturalHeight / ratioWidth);
      } else {
        newWidth = Math.round(naturalWidth / ratioHeight);
      }

      if (newWidth !== updatedModel.width || newHeight !== updatedModel.height) {
        onSaveConfigure({
          id,
          snapshot: { ...updatedModel, width: newWidth, height: newHeight },
        });
      }
    },
    [onSaveConfigure, id],
  );

  const imageStyles: CSSProperties = { width, height };

  return ready ? (
    <img
      ref={imageContainerRef}
      onLoad={() => adjustImageSize(model)}
      draggable={false}
      alt={alt}
      src={imgSrc}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';
export default ImageAuthor;
