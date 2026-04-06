import React, { useCallback, useEffect, useMemo, useRef } from 'react';
import { useCommandTarget } from 'components/editing/elements/command_button/useCommandTarget';
import * as ContentModel from 'data/content/model/elements/types';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';

const getSafeIframeSrc = (src?: string): string | undefined => {
  if (!src) return undefined;
  try {
    const url = new URL(src, window.location.href);
    return url.protocol === 'http:' || url.protocol === 'https:' ? src : undefined;
  } catch {
    return undefined;
  }
};

const getTargetOrigin = (src?: string) => {
  if (!src) return null;
  try {
    return new URL(src, window.location.href).origin;
  } catch {
    return null;
  }
};

export const WebpageEmbed: React.FC<{
  webpage: ContentModel.Webpage;
  pointMarkerContext?: PointMarkerContext;
}> = React.memo(({ webpage, pointMarkerContext }) => {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const safeSrc = useMemo(() => getSafeIframeSrc(webpage.src), [webpage.src]);
  const targetOrigin = useMemo(() => getTargetOrigin(safeSrc), [safeSrc]);

  useEffect(() => {
    if (process.env.NODE_ENV === 'production') return;
    if (webpage.targetId) return;
    console.warn(
      'WebpageEmbed missing targetId; command-button targeting will not work for this iframe',
      {
        src: webpage.src,
      },
    );
  }, [webpage.targetId, webpage.src]);

  const onCommandReceived = useCallback(
    (message: string) => {
      if (!targetOrigin) return;
      if (!iframeRef.current?.contentWindow) return;
      iframeRef.current.contentWindow.postMessage(message, targetOrigin);
    },
    [targetOrigin],
  );

  useCommandTarget(webpage.targetId, onCommandReceived);

  const dimensions: { width?: string | number; height?: string | number } = {};
  if (webpage.width) {
    dimensions['width'] = webpage.width;
  }
  if (webpage.height) {
    dimensions['height'] = webpage.height;
  } else if (webpage.width) {
    dimensions['height'] = webpage.width;
  }

  const iframeClass = webpage.width ? '' : 'embed-responsive-item';
  const containerClass = webpage.width ? '' : 'embed-responsive embed-responsive-16by9';

  return (
    <div className={containerClass} {...maybePointMarkerAttr(webpage, pointMarkerContext)}>
      <iframe
        ref={iframeRef}
        id={webpage.id}
        title={webpage.alt || webpage.id || 'Embedded webpage'}
        className={iframeClass}
        {...dimensions}
        allowFullScreen
        src={safeSrc}
      />
    </div>
  );
});

WebpageEmbed.displayName = 'WebpageEmbed';
