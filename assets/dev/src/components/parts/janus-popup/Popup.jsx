var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { getIcon, getIconSrc } from './GetIcon';
import PopupWindow from './PopupWindow';
const Popup = (props) => {
    const [ready, setReady] = useState(false);
    const [model, setModel] = useState(props.model);
    const id = props.id;
    const [context, setContext] = useState(false);
    const [showPopup, setShowPopup] = useState(false);
    const [popupVisible, setPopupVisible] = useState(true);
    const [iconSrc, setIconSrc] = useState('');
    const [initSnapshot, setInitSnapshot] = useState();
    const [activityHost, setActivityHost] = useState(null);
    const handleStylingChanges = () => {
        const styleChanges = {};
        if (width !== undefined) {
            styleChanges.width = { value: width };
        }
        if (height != undefined) {
            styleChanges.height = { value: height };
        }
        props.onResize({ id: `${id}`, settings: styleChanges });
    };
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        const initResult = yield props.onInit({
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
        setActivityHost(initResult.context.host);
        // result of init has a state snapshot with latest (init state applied)
        setInitSnapshot(initResult);
        const currentStateSnapshot = initResult.snapshot;
        const isOpenByDefault = currentStateSnapshot[`stage.${id}.openByDefault`];
        if (isOpenByDefault !== undefined) {
            setShowPopup(isOpenByDefault);
        }
        const isOpen = currentStateSnapshot[`stage.${id}.isOpen`];
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
            }
            else {
                setIconSrc(initIconUrl);
            }
        }
        if (initResult.context.mode === contexts.REVIEW) {
            setContext(false);
        }
        handleStylingChanges();
        setReady(true);
    }), []);
    useEffect(() => {
        const { iconURL, defaultURL } = props.model;
        setShowPopup(!!props.model.openByDefault);
        setPopupVisible(!!props.model.visible);
        setIconSrc(getIconSrc(iconURL, defaultURL));
        initialize(props.model);
    }, [props]);
    const { x, y, z, width, height, customCssClass, openByDefault, visible, defaultURL, iconURL, useToggleBehavior, popup, description, } = model;
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
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (payload) => {
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
                            const isOpen = changes[`stage.${id}.isOpen`];
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
                                }
                                else {
                                    setIconSrc(initIconUrl);
                                }
                            }
                        }
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        {
                            const { snapshot: changes } = payload;
                            const isOpen = changes[`stage.${id}.isOpen`];
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
                                }
                                else {
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
    const iconTriggerStyle = {
        width,
        height,
    };
    // Toggle popup open/close
    const handleToggleIcon = (toggleVal) => {
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
    const partComponents = popup === null || popup === void 0 ? void 0 : popup.partsLayout;
    const config = (popup === null || popup === void 0 ? void 0 : popup.custom) ? popup.custom : null;
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
        };
        return activityHost && ReactDOM.createPortal(<PopupWindow {...windowProps}/>, activityHost);
    };
    return ready ? (<React.Fragment>
      {popupVisible ? (<input data-janus-type={tagName} role="button" {...(iconSrc
            ? {
                src: iconSrc,
                type: 'image',
                alt: description,
            }
            : {
                type: 'button',
            })} className={`info-icon`} aria-controls={id} aria-haspopup="true" aria-label={description} style={iconTriggerStyle} {...(useToggleBehavior
            ? {
                onClick: () => handleToggleIcon(!showPopup),
            }
            : {
                onMouseEnter: () => handleToggleIcon(true),
                onMouseLeave: () => handleToggleIcon(false),
                onFocus: () => handleToggleIcon(true),
                onBlur: () => handleToggleIcon(false),
            })}/>) : null}
      {showPopup ? <PortalWindow /> : null}
    </React.Fragment>) : null;
};
export const tagName = 'janus-popup';
export default Popup;
//# sourceMappingURL=Popup.jsx.map