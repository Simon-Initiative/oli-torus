import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import debounce from 'lodash/debounce';
import { AuthorPartComponentProps } from '../types/parts';
import { ImageModel } from './schema';

const ImageAuthor: React.FC<AuthorPartComponentProps<ImageModel>> = (props) => {
  const { model, onSaveConfigure, id, onReady } = props;
  const { width, height, alt, src, lockAspectRatio, defaultSrc } = model;

  const [ready, setReady] = useState<boolean>(false);
  const imageContainerRef = useRef<HTMLImageElement>(null);

  const debounceImageAdjust = useRef(
    debounce((modelToUpdate: ImageModel) => {
      adjustImageSize(modelToUpdate);
    }, 1000),
  ).current;

  useEffect(() => {
    onReady?.({ id, responses: [] });
    setReady(true);
  }, [id, onReady]);

  const adjustImageSize = useCallback(
    (updatedModel: ImageModel) => {
      const imgEl = imageContainerRef.current;
      if (!imgEl || src === defaultSrc) return;

      const { naturalWidth, naturalHeight, width: currentWidth, height: currentHeight } = imgEl;

      if (naturalWidth <= 0 || naturalHeight <= 0 || currentWidth <= 0 || currentHeight <= 0) {
        return;
      }
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

  useEffect(() => {
    if (src?.length && src !== defaultSrc && lockAspectRatio) {
      debounceImageAdjust(model);
    }
  }, [src, lockAspectRatio, model, debounceImageAdjust]);

  const imageStyles: CSSProperties = { width, height };

  return ready ? (
    <img
      ref={imageContainerRef}
      onLoad={() => lockAspectRatio && adjustImageSize(model)}
      draggable={false}
      alt={alt}
      src={src}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';
export default ImageAuthor;
