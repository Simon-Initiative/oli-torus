var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/* eslint-disable react/prop-types */
import React, { useCallback, useEffect, useState } from 'react';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
const Image = (props) => {
    const [state, setState] = useState(Array.isArray(props.state) ? props.state : []);
    const [model, setModel] = useState(typeof props.model === 'object' ? props.model : {});
    const [ready, setReady] = useState(false);
    const id = props.id;
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        const initResult = yield props.onInit({
            id,
            responses: [],
        });
        /* console.log('IMAGE INIT', initResult); */
        if (initResult) {
            const currentStateSnapshot = initResult.snapshot;
            setState(currentStateSnapshot);
        }
        setReady(true);
    }), []);
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
                /* console.log(`${notificationType.toString()} notification handled [Image]`, payload); */
                switch (notificationType) {
                    case NotificationType.CHECK_STARTED:
                        // nothing to do for images
                        break;
                    case NotificationType.CHECK_COMPLETE:
                        // nothing to do for images
                        break;
                    case NotificationType.STATE_CHANGED:
                        // nothing to do for images
                        // TODO: maybe allow repositioning and changing visiblity, src
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        // nothing to do for images
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
        /* console.log('IMAGE PROPS', props); */
        let pModel;
        let pState;
        if (typeof (props === null || props === void 0 ? void 0 : props.model) === 'string') {
            try {
                pModel = JSON.parse(props.model);
                setModel(pModel);
            }
            catch (err) {
                // bad json, what do?
            }
        }
        if (typeof (props === null || props === void 0 ? void 0 : props.state) === 'string') {
            try {
                pState = JSON.parse(props.state);
                setState(pState);
            }
            catch (err) {
                // bad json, what do?
            }
        }
        if (!pModel) {
            return;
        }
        initialize(pModel);
    }, [props]);
    useEffect(() => {
        if (!ready) {
            return;
        }
        props.onReady({ id, responses: [] });
    }, [ready]);
    const { x, y, z, width, height, src, alt, customCssClass } = model;
    const imageStyles = {
        width,
        height,
        /* zIndex: z, */
    };
    useEffect(() => {
        const styleChanges = {};
        if (width !== undefined) {
            styleChanges.width = { value: width };
        }
        if (height != undefined) {
            styleChanges.height = { value: height };
        }
        props.onResize({ id: `${id}`, settings: styleChanges });
    }, [width, height]);
    return ready ? (<img data-janus-type={tagName} draggable="false" alt={alt} src={src} style={imageStyles}/>) : null;
};
export const tagName = 'janus-image';
export default Image;
//# sourceMappingURL=Image.jsx.map