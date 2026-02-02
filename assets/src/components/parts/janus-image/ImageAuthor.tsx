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

  const { width, height, src, alt, defaultSrc, lockAspectRatio, scaleContent } = model;

  // Detect responsive layout mode (when width is '100%')
  const isResponsiveLayout = width === '100%' || (typeof width === 'string' && width.includes('%'));

  // Build CSS classes based on flag combinations in responsive layout
  const imageClasses = (() => {
    if (!isResponsiveLayout) {
      return '';
    }

    // Build class names based on flag combinations
    const classes: string[] = [];
    if (scaleContent && !lockAspectRatio) {
      classes.push('responsive-image-scale-only');
    } else if (lockAspectRatio && !scaleContent) {
      classes.push('responsive-image-lock-ratio-only');
    } else if (scaleContent && lockAspectRatio) {
      classes.push('responsive-image-scale-lock-both');
    }

    return classes.join(' ');
  })();

  // For non-responsive or when no flags are set, use inline styles
  // For responsive with flags, use CSS custom properties for dynamic values and CSS classes for rules
  const imageStyles: CSSProperties =
    isResponsiveLayout && imageClasses
      ? {
          // Pass original width and height as CSS variables for CSS to use
          ['--image-width' as string]: typeof width === 'number' ? `${width}px` : width,
          ['--image-height' as string]: typeof height === 'number' ? `${height}px` : height,
        }
      : {
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
    // Only adjust size if lockAspectRatio is checked AND we're not in responsive layout with scaleContent
    // When scaleContent is true (including when both flags are checked), CSS handles sizing
    const hasExplicitDimensions = model.width != null && model.height != null;
    const shouldAdjust =
      src?.length &&
      src !== defaultSrc &&
      lockAspectRatio &&
      !(isResponsiveLayout && scaleContent === true) &&
      hasExplicitDimensions;

    if (shouldAdjust) {
      debounceImageAdjust(model);
    }
  }, [model, lockAspectRatio, scaleContent, isResponsiveLayout]);
  const imageContainerRef = useRef<HTMLImageElement>(null);
  const manipulateImageSize = (updatedModel: ImageModel, isfromDebaunce: boolean) => {
    if (!imageContainerRef?.current || !isfromDebaunce) {
      return;
    }

    // Skip saving dimensions when in responsive layout with scaleContent enabled
    // Dimensions will be handled via CSS in this case (either scale-only or both flags)
    const isInResponsiveLayout =
      updatedModel.width === '100%' ||
      (typeof updatedModel.width === 'string' && updatedModel.width.includes('%'));

    // Skip when scaleContent is true (CSS handles sizing for scale-only and both flags)
    if (isInResponsiveLayout && updatedModel.scaleContent === true) {
      return;
    }

    // Only adjust and persist when the model already has both dimensions.
    // If the user removed width or height (for responsive layout), do not re-add them.
    if (updatedModel.width == null || updatedModel.height == null) {
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
        // Only manipulate size if lockAspectRatio is checked AND we're not in responsive layout with scaleContent
        // When scaleContent is true (including when both flags are checked), CSS handles sizing
        if (lockAspectRatio && !(isResponsiveLayout && scaleContent === true)) {
          manipulateImageSize(model, false);
        }
      }}
      draggable="false"
      alt={alt}
      src={src}
      className={imageClasses || undefined}
      style={imageStyles}
    />
  ) : null;
};

export const tagName = 'janus-image';
export default ImageAuthor;
