/* eslint-disable @typescript-eslint/no-non-null-assertion */
/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import PartsLayoutRenderer from '../../activities/adaptive/components/delivery/PartsLayoutRenderer';
import { PartComponentProps } from '../types/parts';
import { getIcon, getIconSrc } from './GetIcon';
import { PopupModel } from './schema';
import { InitResultProps } from './types';

const Popup: React.FC<PartComponentProps<PopupModel>> = (props) => {
  const [ready, setReady] = useState<boolean>(false);
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
  const [context, setContext] = useState<boolean>(false);
  const [showPopup, setShowPopup] = useState(false);
  const [popupVisible, setPopupVisible] = useState(true);
  const [iconSrc, setIconSrc] = useState('');

  const [initSnapshot, setInitSnapshot] = useState<InitResultProps>();
  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
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
    /* console.log('POPUP INIT', initResult); */
    // result of init has a state snapshot with latest (init state applied)
    setInitSnapshot(initResult);
    const currentStateSnapshot = initResult.snapshot;
    const isOpenByDefault: boolean | undefined = currentStateSnapshot[`stage.${id}.openByDefault`];
    if (isOpenByDefault !== undefined) {
      setShowPopup(isOpenByDefault);
    }
    const isOpen: boolean | undefined = currentStateSnapshot[`stage.${id}.isOpen`];
    if (isOpen !== undefined && !isOpenByDefault) {
      setShowPopup(isOpen);
    }
    const isVisible = currentStateSnapshot[`stage.${id}.visible`];
    if (isVisible !== undefined) {
      setPopupVisible(isVisible);
    }
    const initIconUrl = currentStateSnapshot[`stage.${id}.iconURL`];
    if (initIconUrl !== undefined) {
      if (getIcon(initIconUrl)) {
        setIconSrc(getIcon(initIconUrl));
      } else {
        setIconSrc(initIconUrl);
      }
    }
    if (initResult.context.mode === contexts.REVIEW) {
      setContext(false);
    }
    setReady(true);
  }, []);

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

    setShowPopup(!!pModel.openByDefault);
    setPopupVisible(!!pModel.visible);
    setIconSrc(getIconSrc(iconURL, defaultURL));

    initialize(pModel);
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

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [Pop-up]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const isOpen: boolean | undefined = changes[`stage.${id}.isOpen`];
              if (isOpen !== undefined) {
                setShowPopup(isOpen);
                props.onSave({
                  id,
                  responses: [
                    {
                      key: 'isOpen',
                      type: CapiVariableTypes.BOOLEAN,
                      value: isOpen,
                    },
                  ],
                });
              }

              const openByDefault = changes[`stage.${id}.openByDefault`];
              if (openByDefault !== undefined) {
                setShowPopup(parseBool(openByDefault));
              }
              const isVisible = changes[`stage.${id}.visible`];
              if (isVisible !== undefined) {
                setPopupVisible(isVisible);
              }

              const initIconUrl = changes[`stage.${id}.iconURL`];
              if (initIconUrl !== undefined) {
                if (getIcon(initIconUrl)) {
                  setIconSrc(getIcon(initIconUrl));
                } else {
                  setIconSrc(initIconUrl);
                }
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot: changes } = payload;

              const isOpen: boolean | undefined = changes[`stage.${id}.isOpen`];
              if (isOpen !== undefined) {
                setShowPopup(isOpen);
                props.onSave({
                  id,
                  responses: [
                    {
                      key: 'isOpen',
                      type: CapiVariableTypes.BOOLEAN,
                      value: isOpen,
                    },
                  ],
                });
              }
              const isVisible = changes[`stage.${id}.visible`];
              if (isVisible !== undefined) {
                setPopupVisible(isVisible);
              }

              const initIconUrl = changes[`stage.${id}.iconURL`];
              if (initIconUrl !== undefined) {
                if (getIcon(initIconUrl)) {
                  setIconSrc(getIcon(initIconUrl));
                } else {
                  setIconSrc(initIconUrl);
                }
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const popupStyles: CSSProperties = {
    width,
    height,
    /* position: 'absolute',
    top: y,
    left: x,
    zIndex: z,*/
  };

  // Toggle popup open/close
  const handleToggleIcon = (toggleVal: boolean) => {
    setShowPopup(toggleVal);
    // optimistically write state
    props.onSave({
      id,
      responses: [
        {
          key: 'isOpen',
          type: CapiVariableTypes.BOOLEAN,
          value: toggleVal,
        },
      ],
    });
  };
  useEffect(() => {
    const popupModalZ = config?.z || 1000;
    const zIndexIcon = z || 0;
    const finalZIndex = showPopup ? Math.max(zIndexIcon + popupModalZ, popupModalZ) : zIndexIcon;
    const modifiedData = { zIndex: { value: finalZIndex } };
    if (finalZIndex) {
      props.onResize({ id: `${id}`, settings: modifiedData });
    }
  }, [showPopup, model]);
  const handlePartInit = () => {
    return initSnapshot;
  };
  const partComponents = popup?.partsLayout;

  const config = popup?.custom ? popup.custom : null;
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
  const modalX = (config?.x || 0) - x;
  const modalY = (config?.y || 0) - y;
  popupModalStyles.left = modalX;
  popupModalStyles.top = modalY;
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

  if (showPopup) {
    /* console.log('SHOW POPUP: ', { model, popupModalStyles }); */
  }

  return ready ? (
    <React.Fragment>
      {popupVisible ? (
        <input
          data-janus-type={tagName}
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
          className={`info-icon`}
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
            <div
              className={`info-icon-popup ${config?.customCssClass ? config.customCssClass : ''}`}
              style={popupModalStyles}
            >
              <div className="popup-background" style={popupBGStyles}>
                <PartsLayoutRenderer
                  onPartInit={handlePartInit}
                  parts={partComponents}
                ></PartsLayoutRenderer>
                <button
                  aria-label="Close"
                  className="close"
                  style={popupCloseStyles}
                  onClick={() => handleToggleIcon(false)}
                >
                  <span>x</span>
                </button>
              </div>
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
