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
const Designer: React.FC<any> = React.memo(({ screenModel, onChange, portal }) => {
  /* console.log('PopupAuthor: Designer', { screenModel, portal }); */
  return (
    portal &&
    ReactDOM.createPortal(<ScreenAuthor screen={screenModel} onChange={onChange} />, portal)
  );
});

const PopupAuthor: React.FC<AuthorPartComponentProps<PopupModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;

  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  useEffect(() => {
    // console.log('PopupAuthor configuremode changed!!', configuremode);
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const [context, setContext] = useState<ContextProps>({ currentActivity: '', mode: '' });
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
    x,
    y,
    z,
    width,
    height,
    customCssClass,
    openByDefault,
    visible = true,
    defaultURL,
    iconURL,
    useToggleBehavior,
    description,
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

  const styles: CSSProperties = {
    width,
    height,
  };

  // for authoring we don't actually want to hide it
  if (!visible) {
    styles.opacity = 0.5;
  }

  const init = useCallback(async () => {
    const initResult = await props.onInit({ id, responses: [] });
    console.log('PA INIT', { id, initResult });

    setContext((c) => ({ ...c, ...initResult.context }));

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
        <Designer screenModel={windowModel} onChange={handleScreenAuthorChange} portal={portalEl} />
      )}
      <input
        role="button"
        draggable="false"
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
        onDoubleClick={() => {
          setShowWindow(true);
        }}
        aria-controls={id}
        aria-haspopup="true"
        aria-label={description}
        style={styles}
      />
      {showWindow && <PortalWindow />}
    </React.Fragment>
  );
};

export const tagName = 'janus-popup';

export default PopupAuthor;
