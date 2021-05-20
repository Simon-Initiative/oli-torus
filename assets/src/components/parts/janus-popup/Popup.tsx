/* eslint-disable @typescript-eslint/no-non-null-assertion */
/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { parseBoolean } from 'utils/common';
import { getIcon } from './GetIcon';
import PartsLayoutRenderer from '../../../apps/delivery/components/PartsLayoutRenderer';

// TODO: fix typing
const Popup: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
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
    popupEnsembleRef,
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

  const [showPopup, setShowPopup] = useState(parseBoolean(openByDefault));
  const [popupVisible, setPopupVisible] = useState(parseBoolean(visible));

  const getIconSrc = () => {
    if (iconURL && getIcon(iconURL)) {
      return getIcon(iconURL);
    } else if (iconURL) {
      return iconURL;
    } else {
      return getIcon(defaultURL!);
    }
  };
  const [iconSrc, setIconSrc] = useState(getIconSrc);

  // useEffect(() => {
  //   onReady({
  //     activityId: `${id}`,
  //     partResponses: [
  //       {
  //         id: `stage.${id}.isOpen`,
  //         key: 'isOpen',
  //         type: CapiVariableTypes.BOOLEAN,
  //         value: false,
  //       },
  //       {
  //         id: `stage.${id}.openByDefault`,
  //         key: 'openByDefault',
  //         type: CapiVariableTypes.BOOLEAN,
  //         value: openByDefault,
  //       },
  //       {
  //         id: `stage.${id}.visible`,
  //         key: 'visible',
  //         type: CapiVariableTypes.BOOLEAN,
  //         value: true, // TODO: need a prop?
  //       },
  //     ],
  //   });
  // }, []);

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
    //   activityId: `${id}`,
    //   partResponses: [
    //     {
    //       id: `stage.${id}.isOpen`,
    //       key: 'isOpen',
    //       type: CapiVariableTypes.BOOLEAN,
    //       value: toggleVal,
    //     },
    //   ],
    // });
  };
  const partComponents = popupEnsembleRef.activities.reduce((components: any[], activity: any) => {
    components.push(activity);
    return components;
  }, []);
  return (
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
          {popupEnsembleRef && popupEnsembleRef.id && popupEnsembleRef.activities ? (
            <PartsLayoutRenderer
              parts ={partComponents}
            ></PartsLayoutRenderer>
          ) : (
            <div>Popup could not load</div>
          )}
        </React.Fragment>
      ) : null}
    </React.Fragment>
  );
};

export const tagName = 'janus-popup';

export default Popup;
