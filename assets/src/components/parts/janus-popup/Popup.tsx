import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Environment } from 'janus-script';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import { getIcon, getIconSrc } from './GetIcon';
import PopupWindow from './PopupWindow';
import { PopupModel } from './schema';
import { InitResultProps } from './types';

const Popup: React.FC<PartComponentProps<PopupModel>> = (props) => {
  const [ready, setReady] = useState<boolean>(false);
  const [model, _setModel] = useState<any>(props.model);
  const id: string = props.id;
  const [_context, setContext] = useState<boolean>(false);
  const [showPopup, setShowPopup] = useState(false);
  const [popupVisible, setPopupVisible] = useState(true);
  const [iconSrc, setIconSrc] = useState('');
  const [scriptEnv, setScriptEnv] = useState<any>();
  const [initSnapshot, setInitSnapshot] = useState<InitResultProps>();

  const [activityHost, setActivityHost] = useState<any>(null);
  const handleStylingChanges = () => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }
    props.onResize({ id: `${id}`, settings: styleChanges });
  };
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
        {
          key: 'userOpened',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
      ],
    });

    /* console.log('POPUP INIT', initResult); */
    setActivityHost(initResult.context.host);

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
    if (initResult.env) {
      const env = new Environment(initResult.env);
      setScriptEnv(env);
    }
    handleStylingChanges();
    setReady(true);
  }, []);

  useEffect(() => {
    const { iconURL, defaultURL } = props.model;

    setShowPopup(!!props.model.openByDefault);
    setPopupVisible(!!props.model.visible);
    setIconSrc(getIconSrc(iconURL, defaultURL));

    initialize(props.model);
  }, [props]);

  const { width, height, useToggleBehavior, popup, description } = model;

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
              if (isOpen !== undefined && showPopup !== isOpen) {
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

  useEffect(() => {
    if (showPopup) {
      //When the student opens the popup, userOpened changes to true and stays true even if the popup is closed.
      props.onSave({
        id,
        responses: [
          {
            key: 'userOpened',
            type: CapiVariableTypes.BOOLEAN,
            value: true,
          },
        ],
      });
    }
  }, [showPopup]);
  const iconTriggerStyle: CSSProperties = {
    width,
    height,
  };

  // Toggle popup open/close
  const handleToggleIcon = (toggleVal: boolean) => {
    setShowPopup(toggleVal);
    if (toggleVal === false) {
      // set focus on inputRef
      if (inputRef.current) {
        inputRef.current.focus();
      }
    }
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

  const handleOnBlurToggleIcon = (toggleVal: boolean) => {
    setShowPopup(toggleVal);
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

  const partComponents = popup?.partsLayout;
  const config = popup?.custom ? popup.custom : null;

  const PortalWindow = () => {
    if (!initSnapshot) {
      return null;
    }
    const windowProps = {
      config,
      parts: partComponents,
      snapshot: initSnapshot.snapshot,
      context: initSnapshot.context,
      onClose: () => handleToggleIcon(false),
      env: scriptEnv,
    };
    return activityHost && ReactDOM.createPortal(<PopupWindow {...windowProps} />, activityHost);
  };

  const inputRef = useRef<HTMLInputElement>(null);

  return ready ? (
    <React.Fragment>
      {popupVisible ? (
        <input
          ref={inputRef}
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
          style={iconTriggerStyle}
          {...(useToggleBehavior
            ? {
                onClick: () => handleToggleIcon(!showPopup),
              }
            : {
                onMouseEnter: () => handleToggleIcon(true),
                onMouseLeave: () => handleToggleIcon(false),
                onFocus: () => handleToggleIcon(true),
                onBlur: () => handleOnBlurToggleIcon(false),
              })}
        />
      ) : null}
      {showPopup ? <PortalWindow /> : null}
    </React.Fragment>
  ) : null;
};

export const tagName = 'janus-popup';

export default Popup;
