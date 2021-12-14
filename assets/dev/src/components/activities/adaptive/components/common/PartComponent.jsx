var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import React, { useContext, useEffect, useRef, useState, useCallback } from 'react';
import { NotificationContext, NotificationType, subscribeToNotification, } from '../../../../../apps/delivery/components/NotificationContext';
import { tagName as UnknownTag } from './UnknownPart';
const stubHandler = () => __awaiter(void 0, void 0, void 0, function* () {
    return;
});
const PartComponent = (props) => {
    const pusherContext = useContext(NotificationContext);
    const initialStyles = {
        display: 'block',
        position: 'absolute',
        top: props.model.y,
        left: props.model.x,
        zIndex: props.model.z || 0,
    };
    const [componentStyle, setComponentStyle] = useState(initialStyles);
    const [customCssClass, setCustomCssClass] = useState(props.model.customCssClass || '');
    const handleStylingChanges = (currentStateSnapshot) => {
        const styleChanges = {};
        const sX = currentStateSnapshot[`stage.${props.id}.IFRAME_frameX`];
        if (sX !== undefined) {
            styleChanges.left = sX;
        }
        const sY = currentStateSnapshot[`stage.${props.id}.IFRAME_frameY`];
        if (sY !== undefined) {
            styleChanges.top = sY;
        }
        const sZ = currentStateSnapshot[`stage.${props.id}.IFRAME_frameZ`];
        if (sZ !== undefined) {
            styleChanges.zIndex = sZ;
        }
        const sWidth = currentStateSnapshot[`stage.${props.id}.IFRAME_frameWidth`];
        if (sWidth !== undefined) {
            styleChanges.width = sWidth;
        }
        const sHeight = currentStateSnapshot[`stage.${props.id}.IFRAME_frameHeight`];
        if (sHeight !== undefined) {
            styleChanges.height = sHeight;
        }
        setComponentStyle((previousStyle) => {
            return Object.assign(Object.assign({}, previousStyle), styleChanges);
        });
        const sCssClass = currentStateSnapshot[`stage.${props.id}.IFRAME_frameCssClass`];
        if (sCssClass !== undefined) {
            setCustomCssClass(sCssClass);
        }
        const sCustomCssClass = currentStateSnapshot[`stage.${props.id}.customCssClass`];
        if (sCustomCssClass !== undefined) {
            setCustomCssClass(sCustomCssClass);
        }
    };
    const onResize = useCallback((payload) => __awaiter(void 0, void 0, void 0, function* () {
        const settings = payload.settings;
        const styleChanges = {};
        if (settings === null || settings === void 0 ? void 0 : settings.width) {
            styleChanges.width = settings.width.value;
        }
        if (settings === null || settings === void 0 ? void 0 : settings.height) {
            styleChanges.height = settings.height.value;
        }
        if (settings === null || settings === void 0 ? void 0 : settings.zIndex) {
            const newZ = settings.zIndex.value;
            styleChanges.zIndex = newZ;
        }
        setComponentStyle((previousStyle) => {
            return Object.assign(Object.assign({}, previousStyle), styleChanges);
        });
        return true;
    }), [componentStyle]);
    const [wcEvents, setWcEvents] = useState({
        init: props.onInit,
        ready: props.onReady,
        save: props.onSave,
        submit: props.onSubmit,
        resize: props.onResize,
        getData: props.onGetData || stubHandler,
        setData: props.onSetData || stubHandler,
        // authoring
        configure: props.onConfigure || stubHandler,
        saveconfigure: props.onSaveConfigure || stubHandler,
        cancelconfigure: props.onCancelConfigure || stubHandler,
    });
    useEffect(() => {
        setWcEvents({
            init: props.onInit,
            ready: props.onReady,
            save: props.onSave,
            submit: props.onSubmit,
            resize: props.onResize,
            getData: props.onGetData || stubHandler,
            setData: props.onSetData || stubHandler,
            // authoring
            configure: props.onConfigure || stubHandler,
            saveconfigure: props.onSaveConfigure || stubHandler,
            cancelconfigure: props.onCancelConfigure || stubHandler,
        });
    }, [
        props.onInit,
        props.onReady,
        props.onSave,
        props.onSubmit,
        props.onResize,
        props.onGetData,
        props.onSetData,
        props.onConfigure,
        props.onSaveConfigure,
        props.onCancelConfigure,
    ]);
    const ref = useRef(null);
    useEffect(() => {
        if (!pusherContext) {
            return;
        }
        const notificationsHandled = [
            NotificationType.CHECK_STARTED,
            NotificationType.CHECK_COMPLETE,
            NotificationType.CONTEXT_CHANGED,
            NotificationType.STATE_CHANGED,
            NotificationType.CONFIGURE,
            NotificationType.CONFIGURE_SAVE,
            NotificationType.CONFIGURE_CANCEL,
        ];
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (e) => {
                /* console.log(`${notificationType.toString()} notification handled [PC : ${props.id}]`, e); */
                const el = ref.current;
                if (el) {
                    if (el.notify) {
                        if (notificationType === NotificationType.CONTEXT_CHANGED ||
                            notificationType === NotificationType.STATE_CHANGED) {
                            handleStylingChanges(e.snapshot || e.mutateChanges);
                        }
                        el.notify(notificationType.toString(), e);
                    }
                }
            };
            const unsub = subscribeToNotification(pusherContext, notificationType, handler);
            return unsub;
        });
        return () => {
            notifications.forEach((unsub) => {
                unsub();
            });
        };
    }, [pusherContext]);
    const [listening, setIsListening] = useState(false);
    useEffect(() => {
        const wcEventHandler = (e) => __awaiter(void 0, void 0, void 0, function* () {
            const { payload, callback } = e.detail;
            if (payload.id !== props.id) {
                // because we need to listen to document we'll get all part component events
                // each PC adds a listener, so we need to filter out our own here
                return;
            }
            const handler = wcEvents[e.type];
            if (handler) {
                // TODO: refactor all handlers to take ID and send it here
                const result = yield handler(payload);
                if (e.type === 'resize') {
                    onResize(payload);
                }
                if (callback) {
                    callback(result);
                }
            }
        });
        Object.keys(wcEvents).forEach((eventName) => {
            document.addEventListener(eventName, wcEventHandler);
        });
        setIsListening(true);
        return () => {
            Object.keys(wcEvents).forEach((eventName) => {
                document.removeEventListener(eventName, wcEventHandler);
            });
        };
    }, [wcEvents, onResize]);
    const webComponentProps = Object.assign(Object.assign({ ref }, props), { model: JSON.stringify(props.model), state: JSON.stringify(props.state), customCssClass });
    let wcTagName = props.type;
    if (!wcTagName || !customElements.get(wcTagName)) {
        wcTagName = UnknownTag;
    }
    // if we pass in style then it will be controlled and so nothing else can use it
    if (!props.editMode) {
        webComponentProps.style = componentStyle;
        // console.log('DELIVERY RENDER:', wcTagName, props);
    }
    // don't render until we're listening because otherwise the init event will post too fast
    return listening ? React.createElement(wcTagName, webComponentProps) : null;
};
export default PartComponent;
//# sourceMappingURL=PartComponent.jsx.map