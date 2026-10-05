import React, { CSSProperties, useEffect, useLayoutEffect, useRef, useState } from 'react';
import chroma from 'chroma-js';
import { Environment } from 'janus-script';
import PartsLayoutRenderer from 'components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import guid from 'utils/guid';
import { getPopupDescriptionText } from './popupAccessibility';
import { ContextProps, InitResultProps } from './types';

interface PopupWindowProps {
  /** Short dialog name, separate from its reading target or rendered description. */
  accessibleName: string;
  config: any;
  parts: any[];
  context: ContextProps;
  snapshot?: Record<string, unknown>;
  onClose?: () => void;
  env?: Environment;
}

const PopupWindow: React.FC<PopupWindowProps> = ({
  accessibleName,
  config,
  parts,
  context,
  onClose,
  snapshot = {},
  env,
}) => {
  //setting it to false for now until we fix the pop-up responsive layout issues
  const responsiveLayout = false; //context?.responsiveLayout ?? false;
  const popupModalStyles: CSSProperties = {
    width: config?.width || 300,
  };
  const dialogRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const readingRef = useRef<HTMLParagraphElement>(null);
  const initialFocus = useRef({ placed: false, reading: false });
  const [contentId] = useState(() => `popup-content-${guid()}`);
  const [descriptionText, setDescriptionText] = useState<string | null>(null);
  const hasInformationalParts = parts.every((part) =>
    ['janus-text-flow', 'janus-image'].includes(part.type),
  );

  useLayoutEffect(() => {
    const content = contentRef.current;
    if (!content || !hasInformationalParts) {
      setDescriptionText(null);
      return;
    }

    const updateDescription = () => setDescriptionText(getPopupDescriptionText(content));
    updateDescription();
    const observer = new MutationObserver(updateDescription);
    observer.observe(content, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: [
        'alt',
        'aria-label',
        'aria-hidden',
        'hidden',
        'style',
        'class',
        'href',
        'tabindex',
        'contenteditable',
      ],
    });
    return () => observer.disconnect();
  }, [hasInformationalParts, parts]);
  if (config?.palette) {
    if (config.palette.useHtmlProps) {
      popupModalStyles.backgroundColor = config.palette.backgroundColor;
      popupModalStyles.borderColor = config.palette.borderColor;
      popupModalStyles.borderWidth = config.palette.borderWidth;
      popupModalStyles.borderStyle = config.palette.borderStyle;
      popupModalStyles.borderRadius = config.palette.borderRadius;
    } else {
      popupModalStyles.borderWidth = `${
        config?.palette?.lineThickness ? config?.palette?.lineThickness + 'px' : '1px'
      }`;
      popupModalStyles.borderRadius = '10px';
      popupModalStyles.borderStyle = 'solid';
      popupModalStyles.borderColor = `rgba(${
        config?.palette?.lineColor || config?.palette?.lineColor === 0
          ? chroma(config?.palette?.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${config?.palette?.lineAlpha})`;
      popupModalStyles.backgroundColor = `rgba(${
        config?.palette?.fillColor || config?.palette?.fillColor === 0
          ? chroma(config?.palette?.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${config?.palette?.fillAlpha})`;
    }
  }

  popupModalStyles.left = config.x || 0;
  popupModalStyles.top = config.y || 0;
  popupModalStyles.zIndex = config.z || 1000;
  popupModalStyles.height = config.height || 0;
  popupModalStyles.overflow = 'hidden';
  popupModalStyles.position = 'absolute';

  const popupCloseStyles: CSSProperties = {
    position: 'absolute',
    padding: 0,
    zIndex: (config.z || 1000) + 1,
    background: 'transparent',
    textDecoration: 'none',
    width: '25px',
    height: '25px',
    fontSize: '1.4em',
    fontFamily: 'Arial',
    right: 0,
    opacity: 1,
  };

  const popupBGStyles: CSSProperties = {
    top: 0,
    left: 0,
    bottom: 0,
    right: 0,
    borderRadius: 10,
    padding: 0,
    overflow: 'hidden',
    width: '100%',
    height: '100%',
  };

  const closeButtonSpanStyles: CSSProperties = {
    marginLeft: 12,
    padding: 0,
    textShadow: 'none',
    top: 0,
    left: 0,
    bottom: 0,
    fontWeight: 'bold',
    fontFamily: 'Arial',
    marginTop: -6,
    position: 'absolute',
    right: 0,
  };

  const handleCloseIconClick = (e: any) => {
    if (onClose) {
      onClose();
    }
  };

  const handlePartInit = async ({ id, responses }: { id: string; responses: any[] }) => {
    const result: InitResultProps = {
      snapshot,
      context,
      env,
    };

    /*   console.log('PopupWindow.handlePartInit', { result, id, responses }); */

    return result;
  };
  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      const dialog = dialogRef.current;
      if (!dialog || initialFocus.current.reading) {
        return;
      }

      if (!initialFocus.current.placed || document.activeElement === dialog) {
        const target = readingRef.current ?? dialog;
        target.focus({ preventScroll: true });
        initialFocus.current = { placed: true, reading: target === readingRef.current };
      }
    });
    return () => cancelAnimationFrame(frame);
  }, [descriptionText]);

  return (
    <div
      ref={dialogRef}
      role="dialog"
      aria-modal="true"
      aria-label={accessibleName}
      aria-describedby={descriptionText ? undefined : contentId}
      tabIndex={-1}
      className={`info-icon-popup ${config?.customCssClass ? config.customCssClass : ''}`}
      style={popupModalStyles}
    >
      <div className="popup-background" style={popupBGStyles}>
        {descriptionText && (
          <p id={`${contentId}-description`} ref={readingRef} className="sr-only" tabIndex={-1}>
            {descriptionText}
          </p>
        )}
        <div id={contentId} ref={contentRef}>
          <PartsLayoutRenderer
            onPartInit={handlePartInit}
            parts={parts}
            responsiveLayout={responsiveLayout}
          ></PartsLayoutRenderer>
        </div>

        <button
          aria-label="Close"
          className="close"
          style={popupCloseStyles}
          onClick={handleCloseIconClick}
        >
          <span aria-hidden={true} style={closeButtonSpanStyles}>
            x
          </span>
        </button>
      </div>
    </div>
  );
};

export default PopupWindow;
