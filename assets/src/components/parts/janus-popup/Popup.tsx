/* eslint-disable @typescript-eslint/no-non-null-assertion */
/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import React, { CSSProperties, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import PartsLayoutRenderer from '../../../apps/delivery/components/PartsLayoutRenderer';
import { getIcon } from './GetIcon';

// TODO: fix typing
const Popup: React.FC<any> = (props) => {
  const [ready, setReady] = useState<boolean>(false);
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;

  const [showPopup, setShowPopup] = useState(false);
  const [popupVisible, setPopupVisible] = useState(true);
  const [iconSrc, setIconSrc] = useState('');

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }

    const { iconURL, defaultURL } = pModel;
    const getIconSrc = () => {
      if (iconURL && getIcon(iconURL)) {
        return getIcon(iconURL);
      } else if (iconURL) {
        return iconURL;
      } else {
        return getIcon(defaultURL!);
      }
    };

    setShowPopup(!!pModel.openByDefault);
    setPopupVisible(!!pModel.visible);
    setIconSrc(getIconSrc());

    props.onInit({
      id,
      responses: [
        {
          key: 'visible',
          type: CapiVariableTypes.BOOLEAN,
          value: !!pModel.visible,
        },
        {
          key: 'openByDefault',
          type: CapiVariableTypes.BOOLEAN,
          value: !!pModel.openByDefault,
        },
        {
          key: 'isOpen',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
      ],
    });
    setReady(true);
  }, [props]);

  const {
    x,
    y,
    z,
    width,
    height,
    customCssClass,
    openByDefault,
    visible,
    defaultURL,
    iconURL,
    useToggleBehavior,
    popup,
    description,
  } = model;

  const popupStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };

  // const handleActivityStateChange = (stateData) => {
  //   // override text value from state
  //   const interested = stateData.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
  //   if (interested?.length) {
  //     interested.forEach((stateVar) => {
  //       if (stateVar.key === 'openByDefault') {
  //         const stateIsOpenByDefault: boolean = parseBool(stateVar.value);
  //         if (stateIsOpenByDefault) {
  //           setShowPopup(stateIsOpenByDefault);
  //         }
  //       }
  //       if (stateVar.key === 'isOpen') {
  //         const stateIsOpen: boolean = parseBool(stateVar.value);
  //         setShowPopup(stateIsOpen);
  //       }
  //       if (stateVar.key === 'iconURL' && stateVar.value) {
  //         setIconSrc(stateVar.value.toString());
  //       }
  //       if (stateVar.key === 'visible') {
  //         const stateIsVisible: boolean = parseBool(stateVar.value);
  //         setPopupVisible(stateIsVisible);
  //       }
  //     });
  //   }
  // };

  // useEffect(() => {
  //   const mutateStateHandler = (data) => {
  //     handleActivityStateChange(data);
  //   };
  //   componentEventService.on('mutate', ({ data }) => {
  //     mutateStateHandler(data);
  //   });
  //   return () => {
  //     componentEventService.off('mutate', mutateStateHandler);
  //   };
  // }, []);

  // useEffect(() => {
  //   const initHappend = (data) => {
  //     handleActivityStateChange(data);
  //   };
  //   componentEventService.on('init', ({ data }) => {
  //     initHappend(data);
  //   });
  //   return () => {
  //     componentEventService.off('init', initHappend);
  //   };
  // }, []);

  // Toggle popup open/close
  const handleToggleIcon = (toggleVal: boolean) => {
    setShowPopup(toggleVal);
    // optimistically write state
    // onSaveActivity({
    //   id: `${id}`,
    //   responses: [
    //     {
    //       key: 'isOpen',
    //       type: CapiVariableTypes.BOOLEAN,
    //       value: toggleVal,
    //     },
    //   ],
    // });
  };

  const partComponents = popup?.partsLayout;

  const config = popup?.custom? popup.custom : null;
  const popupModalStyles: CSSProperties = {
    width: config?.width || 1300,
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
            config?.palette?.lineThickness
                ? config?.palette?.lineThickness + 'px'
                : '1px'
        }`;
        popupModalStyles.borderRadius = '10px';
        popupModalStyles.borderStyle = 'solid';
        popupModalStyles.borderColor = `rgba(${
            config?.palette?.lineColor ||
            config?.palette?.lineColor === 0
                ? chroma(config?.palette?.lineColor).rgb().join(',')
                : '255, 255, 255'
        },${config?.palette?.lineAlpha})`;
        popupModalStyles.backgroundColor = `rgba(${
            config?.palette?.fillColor ||
            config?.palette?.fillColor === 0
                ? chroma(config?.palette?.fillColor).rgb().join(',')
                : '255, 255, 255'
        },${config?.palette?.fillAlpha})`;
    }
}
    popupModalStyles.left = config?.x? config.x : 0; // adding the previous logic done for Pop-up and feedback.
    popupModalStyles.top = config?.y? config.y : 0; // adding the previous logic done for Pop-up and feedback.
    popupModalStyles.zIndex = config?.z ? config?.z : 1000;
    popupModalStyles.height = config?.height;
    popupModalStyles.overflow = 'hidden';
    popupModalStyles.position = 'absolute';

    const popupCloseStyles: CSSProperties = {
      position: 'absolute',
      padding: 0,
      zIndex: 5000,
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
  return ready ? (
    <React.Fragment>
      {popupVisible ? (
        <input
          data-janus-type={props.type}
          id={id}
          role="button"
          {...(iconSrc
            ? {
                src: iconSrc,
                type: 'image',
                alt: description,
              }
            : {
                type: 'button',
              })}
          className={`info-icon ${customCssClass}`}
          aria-controls={id}
          aria-haspopup="true"
          aria-label={description}
          style={popupStyles}
          {...(useToggleBehavior
            ? {
                onClick: () => handleToggleIcon(!showPopup),
              }
            : {
                onMouseEnter: () => handleToggleIcon(true),
                onMouseLeave: () => handleToggleIcon(false),
                onFocus: () => handleToggleIcon(true),
                onBlur: () => handleToggleIcon(false),
              })}
        />
      ) : null}
      {showPopup ? (
        <React.Fragment>
          {partComponents ? (
            <div className={`info-icon-popup ${config?.customCssClass? config.customCssClass : '' }`}
             style={popupModalStyles}>
              (
                    <div className="popup-background" style={popupBGStyles}>
                      <PartsLayoutRenderer parts={partComponents}></PartsLayoutRenderer>
                        <button
                            aria-label="Close"
                            className="close"
                            style={popupCloseStyles}
                            onClick={() => handleToggleIcon(false)}
                        >
                            <span>x</span>
                        </button>
                    </div>
                )
            </div>
          ) : (
            <div>Popup could not load</div>
          )}
        </React.Fragment>
      ) : null}
    </React.Fragment>
  ) : null;
};

export const tagName = 'janus-popup';

export default Popup;
