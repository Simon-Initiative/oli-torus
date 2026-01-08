import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import ScreenAuthor from 'components/activities/adaptive/components/authoring/ScreenAuthor';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import { getIconSrc } from './GetIcon';
import PopupWindow from './PopupWindow';
import { PopupModel } from './schema';
import { ContextProps } from './types';

// eslint-disable-next-line react/display-name
const Designer: React.FC<any> = React.memo(
  ({ screenModel, onChange, portal, responsiveLayout }) => {
    return (
      portal &&
      ReactDOM.createPortal(
        <ScreenAuthor
          screen={screenModel}
          onChange={onChange}
          responsiveLayout={responsiveLayout}
        />,
        portal,
      )
    );
  },
);

const PopupAuthor: React.FC<AuthorPartComponentProps<PopupModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onSaveConfigure } = props;

  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  useEffect(() => {
    // console.log('PopupAuthor configuremode changed!!', configuremode);
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const [context, setContext] = useState<ContextProps>({ currentActivity: '', mode: '' });
  const [responsiveLayout, setResponsiveLayout] = useState<boolean>(false);
  const [showWindow, setShowWindow] = useState(false);

  const [windowModel, setWindowModel] = useState<any>(model.popup);
  useEffect(() => {
    // console.log('PopupAuthor windowModel changed!!', { windowModel, gnu: model.popup });
    setWindowModel(model.popup);
  }, [model.popup]);

  const handleNotificationSave = useCallback(async () => {
    const modelClone = clone(model);
    modelClone.popup = windowModel;
    // console.log('PA:NOTIFYSAVE', { id, modelClone, windowModel });
    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
  }, [windowModel, model]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_SAVE,
      NotificationType.CONFIGURE_CANCEL,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification event [PopupAuthor]`, payload); */
        if (!payload) {
          // if we don't have anything, we won't even have an id to know who it's for
          // for these events we need something, it's not for *all* of them
          return;
        }
        switch (notificationType) {
          case NotificationType.CONFIGURE:
            {
              const { partId, configure } = payload;
              if (partId === id) {
                /* console.log('PA:NotificationType.CONFIGURE', { partId, configure }); */
                // if it's not us, then we shouldn't be configuring
                setInConfigureMode(configure);
                if (configure) {
                  onConfigure({ id, configure, context: { fullscreen: true } });
                }
              }
            }
            break;
          case NotificationType.CONFIGURE_SAVE:
            {
              const { id: partId } = payload;
              if (partId === id) {
                /* console.log('PA:NotificationType.CONFIGURE_SAVE', { partId }); */
                handleNotificationSave();
              }
            }
            break;
          case NotificationType.CONFIGURE_CANCEL:
            {
              const { id: partId } = payload;
              if (partId === id) {
                /* console.log('PA:NotificationType.CONFIGURE_CANCEL', { partId }); */
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
  }, [props.notify, handleNotificationSave]);

  const {
    z,
    width,
    height,
    visible = true,
    defaultURL,
    iconURL,
    description,
    labelText,
    labelPosition = 'right',
    hideIcon = false,
  } = model;

  // need to offset the window position by the position of the parent element
  // since it's a child of the parent element and not the activity (screen) directly
  const offsetWindowConfig = {
    ...model.popup.custom,
    x: model.popup.custom.x /*  - (x || 0) */,
    y: model.popup.custom.y /*  - (y || 0) */,
    z: Math.max((z || 0) + 1000, (model.popup.custom.z || 0) + 1000),
  };

  const [windowConfig, setWindowConfig] = useState<any>(offsetWindowConfig);
  const [windowParts, setWindowParts] = useState<any[]>(model.popup.partsLayout || []);

  // only update when the model updates, not the windowModel, because that is just temporary
  // for the editing until saved
  useEffect(() => {
    setWindowConfig(offsetWindowConfig);
    setWindowParts(model.popup.partsLayout || []);
  }, [model.popup]);

  const handleWindowClose = () => {
    setShowWindow(false);
  };

  const iconSrc = getIconSrc(iconURL, defaultURL);

  // Determine if iconSrc is a standard icon (data URL) or custom URL
  // Standard icons should use CSS background-image, not src attribute
  const isStandardIcon = iconSrc && iconSrc.startsWith('data:');
  const isCustomIcon = iconSrc && !isStandardIcon;

  // Icon should always be fixed size (32x32), not resizable
  const iconTriggerStyle: CSSProperties = {
    width: 32,
    height: 32,
    flexShrink: 0,
  };

  // for authoring we don't actually want to hide it
  if (!visible) {
    iconTriggerStyle.opacity = 0.5;
  }

  // Determine flex direction based on label position
  const getFlexDirection = () => {
    switch (labelPosition) {
      case 'left':
        return 'row-reverse';
      case 'right':
        return 'row';
      case 'top':
        return 'column-reverse';
      case 'bottom':
        return 'column';
      default:
        return 'row';
    }
  };

  // Determine alignment based on label position
  const getAlignItems = () => {
    switch (labelPosition) {
      case 'left':
      case 'right':
        return 'center';
      case 'top':
      case 'bottom':
        return 'center';
      default:
        return 'center';
    }
  };

  // Determine justify content for vertical positions (top/bottom)
  const getJustifyContent = () => {
    switch (labelPosition) {
      case 'top':
      case 'bottom':
        return 'center';
      case 'left':
      case 'right':
        return 'flex-start';
      default:
        return 'flex-start';
    }
  };

  // Container should respect width/height from model
  const containerStyle: CSSProperties = {
    display: 'flex',
    flexDirection: getFlexDirection(),
    alignItems: getAlignItems(),
    justifyContent: getJustifyContent(),
    gap: '10px',
    width: width || 'auto',
    height: height || 'auto',
  };

  const labelStyle: CSSProperties = {
    fontSize: '1rem',
    cursor: 'pointer',
    userSelect: 'none',
    flex: 1,
    minWidth: 0,
    minHeight: 0,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    wordWrap: 'break-word',
  };

  const shouldShowIcon = !hideIcon;
  const shouldShowLabel = labelText && labelText.trim().length > 0;

  const init = useCallback(async () => {
    const initResult = await props.onInit({ id, responses: [] });
    console.log('PA INIT', { id, initResult });

    setContext((c) => ({ ...c, ...initResult.context }));
    setResponsiveLayout(initResult.context?.responsiveLayout ?? false);

    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, [props]);

  useEffect(() => {
    init();
  }, []);

  const handleScreenAuthorChange = (changedScreen: any) => {
    /* console.log('POPUP AUTHOR SCREEN AUTHOR CHANGE', changedScreen); */
    setWindowModel(changedScreen);
  };

  const [portalEl, setPortalEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    // timeout to give modal a moment to load
    setTimeout(() => {
      const el = document.getElementById(props.portal);
      // console.log('portal changed', { el, p: props.portal });
      if (el) {
        setPortalEl(el);
      }
    }, 10);
  }, [inConfigureMode, props.portal]);

  useEffect(() => {
    const popupModalZ = windowModel.z || 1000;
    const zIndexIcon = z || 0;
    const finalZIndex = showWindow ? Math.max(zIndexIcon + popupModalZ, popupModalZ) : zIndexIcon;
    const modifiedData = { zIndex: { value: finalZIndex } };
    // console.log('PA: RESIZE', { id, modifiedData });
    setAuthorStyleOverride(`#${id.replace(/:/g, '\\:')} { z-index: ${finalZIndex};}`);
    props.onResize({ id: `${id}`, settings: modifiedData });
  }, [showWindow, model]);

  const [authorStyleOverride, setAuthorStyleOverride] = useState<string>('');

  const PortalWindow = () => {
    if (!context.host) {
      return null;
    }
    const windowProps = {
      config: windowConfig,
      parts: windowParts,
      snapshot: {},
      context,
      onClose: handleWindowClose,
    };
    return ReactDOM.createPortal(<PopupWindow {...windowProps} />, context.host);
  };

  return (
    <React.Fragment>
      <style>{authorStyleOverride}</style>
      {inConfigureMode && portalEl && (
        <Designer
          screenModel={windowModel}
          onChange={handleScreenAuthorChange}
          portal={portalEl}
          responsiveLayout={responsiveLayout}
        />
      )}
      <div className="popup-container" style={containerStyle}>
        {shouldShowIcon && (
          <input
            role="button"
            draggable="false"
            {...(shouldShowLabel || isStandardIcon
              ? // When label exists or standard icon, don't set src - CSS will apply background-image
                {
                  type: 'button',
                  alt: description,
                }
              : // When no label and custom icon URL, use src
              isCustomIcon
              ? {
                  src: iconSrc,
                  type: 'image',
                  alt: description,
                }
              : {
                  type: 'button',
                })}
            className={`info-icon`}
            onDoubleClick={() => {
              setShowWindow(true);
            }}
            aria-controls={id}
            aria-haspopup="true"
            aria-label={description}
            style={iconTriggerStyle}
          />
        )}
        {shouldShowLabel && (
          <span
            role="button"
            tabIndex={0}
            aria-controls={id}
            aria-haspopup="true"
            aria-label={description}
            style={labelStyle}
            onDoubleClick={() => {
              setShowWindow(true);
            }}
          >
            {labelText}
          </span>
        )}
      </div>
      {showWindow && <PortalWindow />}
    </React.Fragment>
  );
};

export const tagName = 'janus-popup';

export default PopupAuthor;
