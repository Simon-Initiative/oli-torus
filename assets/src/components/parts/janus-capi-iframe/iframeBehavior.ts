import { CSSProperties } from 'react';
import { CapiIframeModel } from './schema';

const INTERNAL_COURSE_LINK_PREFIX = '/course/link/';

export const isInternalPageIframeSource = (
  model: Partial<CapiIframeModel> = {},
  frameSrc = '',
): boolean => {
  return (
    model.sourceType === 'page' ||
    model.linkType === 'page' ||
    (typeof model.sourcePageSlug === 'string' && model.sourcePageSlug.length > 0) ||
    frameSrc.startsWith(INTERNAL_COURSE_LINK_PREFIX)
  );
};

export const shouldAllowIframeScrolling = (
  model: Partial<CapiIframeModel> = {},
  frameSrc = '',
): boolean => {
  return (
    Boolean(model.allowScrolling) ||
    isInternalPageIframeSource(model, frameSrc) ||
    Boolean(frameSrc)
  );
};

export const getIframePartDeliveryStyle = (style: CSSProperties): CSSProperties => ({
  ...style,
  boxSizing: 'border-box',
  maxWidth: '100%',
  maxHeight: '100%',
  overflow: 'hidden',
});

export const getExternalIframeStyles = (
  style: CSSProperties,
  scrollingEnabled: boolean,
): CSSProperties => ({
  ...style,
  display: 'block',
  maxWidth: '100%',
  maxHeight: '100%',
  border: 'none',
  overflow: scrollingEnabled ? 'auto' : 'hidden',
});
