var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { NotificationType, subscribeToNotification, } from 'apps/delivery/components/NotificationContext';
import ScreenAuthor from 'components/activities/adaptive/components/authoring/ScreenAuthor';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import { getIconSrc } from './GetIcon';
import PopupWindow from './PopupWindow';
// eslint-disable-next-line react/display-name
const Designer = React.memo(({ screenModel, onChange, portal }) => {
    /* console.log('PopupAuthor: Designer', { screenModel, portal }); */
    return (portal &&
        ReactDOM.createPortal(<ScreenAuthor screen={screenModel} onChange={onChange}/>, portal));
});
const PopupAuthor = (props) => {
    const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;
    const [inConfigureMode, setInConfigureMode] = useState(parseBoolean(configuremode));
    useEffect(() => {
        // console.log('PopupAuthor configuremode changed!!', configuremode);
        setInConfigureMode(parseBoolean(configuremode));
    }, [configuremode]);
    const [context, setContext] = useState({ currentActivity: '', mode: '' });
    const [showWindow, setShowWindow] = useState(false);
    const [windowModel, setWindowModel] = useState(model.popup);
    useEffect(() => {
        // console.log('PopupAuthor windowModel changed!!', { windowModel, gnu: model.popup });
        setWindowModel(model.popup);
    }, [model.popup]);
    const handleNotificationSave = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        const modelClone = clone(model);
        modelClone.popup = windowModel;
        // console.log('PA:NOTIFYSAVE', { id, modelClone, windowModel });
        yield onSaveConfigure({ id, snapshot: modelClone });
        setInConfigureMode(false);
    }), [windowModel, model]);
    useEffect(() => {
        if (!props.notify) {
            return;
        }
        const notificationsHandled = [
            NotificationType.CONFIGURE,
            NotificationType.CONFIGURE_SAVE,
            NotificationType.CONFIGURE_CANCEL,
        ];
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (payload) => {
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
    const { x, y, z, width, height, customCssClass, openByDefault, visible = true, defaultURL, iconURL, useToggleBehavior, description, } = model;
    // need to offset the window position by the position of the parent element
    // since it's a child of the parent element and not the activity (screen) directly
    const offsetWindowConfig = Object.assign(Object.assign({}, model.popup.custom), { x: model.popup.custom.x /*  - (x || 0) */, y: model.popup.custom.y /*  - (y || 0) */, z: Math.max((z || 0) + 1000, (model.popup.custom.z || 0) + 1000) });
    const [windowConfig, setWindowConfig] = useState(offsetWindowConfig);
    const [windowParts, setWindowParts] = useState(model.popup.partsLayout || []);
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
    const styles = {
        width,
        height,
    };
    // for authoring we don't actually want to hide it
    if (!visible) {
        styles.opacity = 0.5;
    }
    const init = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        const initResult = yield props.onInit({ id, responses: [] });
        console.log('PA INIT', { id, initResult });
        setContext((c) => (Object.assign(Object.assign({}, c), initResult.context)));
        // all activities *must* emit onReady
        props.onReady({ id: `${props.id}` });
    }), [props]);
    useEffect(() => {
        init();
    }, []);
    const handleScreenAuthorChange = (changedScreen) => {
        /* console.log('POPUP AUTHOR SCREEN AUTHOR CHANGE', changedScreen); */
        setWindowModel(changedScreen);
    };
    const [portalEl, setPortalEl] = useState(null);
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
    const [authorStyleOverride, setAuthorStyleOverride] = useState('');
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
        return ReactDOM.createPortal(<PopupWindow {...windowProps}/>, context.host);
    };
    return (<React.Fragment>
      <style>{authorStyleOverride}</style>
      {inConfigureMode && portalEl && (<Designer screenModel={windowModel} onChange={handleScreenAuthorChange} portal={portalEl}/>)}
      <input role="button" draggable="false" {...(iconSrc
        ? {
            src: iconSrc,
            type: 'image',
            alt: description,
        }
        : {
            type: 'button',
        })} className={`info-icon`} onDoubleClick={() => {
            setShowWindow(true);
        }} aria-controls={id} aria-haspopup="true" aria-label={description} style={styles}/>
      {showWindow && <PortalWindow />}
    </React.Fragment>);
};
export const tagName = 'janus-popup';
export default PopupAuthor;
//# sourceMappingURL=PopupAuthor.jsx.map