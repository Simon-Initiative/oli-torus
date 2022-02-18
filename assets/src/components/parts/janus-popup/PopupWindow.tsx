import chroma from 'chroma-js';
import PartsLayoutRenderer from 'components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import React, { CSSProperties, useEffect, useRef } from 'react';
import { ContextProps, InitResultProps } from './types';

interface PopupWindowProps {
  config: any;
  parts: any[];
  context: ContextProps;
  snapshot?: Record<string, unknown>;
  onClose?: () => void;
}

const PopupWindow: React.FC<PopupWindowProps> = ({
  config,
  parts,
  context,
  onClose,
  snapshot = {},
}) => {
  const popupModalStyles: CSSProperties = {
    width: config?.width || 300,
  };
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

  // position is an offset from the parent element now
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
    };

    /*   console.log('PopupWindow.handlePartInit', { result, id, responses }); */

    return result;
  };

  const closeBtnRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (closeBtnRef.current) {
      closeBtnRef.current.focus();
    }
  }, []);

  return (
    <div
      className={`info-icon-popup ${config?.customCssClass ? config.customCssClass : ''}`}
      style={popupModalStyles}
    >
      <div className="popup-background" style={popupBGStyles}>
        <button
          aria-label="Close"
          className="close"
          style={popupCloseStyles}
          onClick={handleCloseIconClick}
          ref={closeBtnRef}
        >
          <span aria-hidden={true} style={closeButtonSpanStyles}>
            x
          </span>
        </button>
        <PartsLayoutRenderer onPartInit={handlePartInit} parts={parts}></PartsLayoutRenderer>
      </div>
    </div>
  );
};

export default PopupWindow;
