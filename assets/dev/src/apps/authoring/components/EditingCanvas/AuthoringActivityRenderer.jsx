var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { saveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { selectCurrentSelection } from 'apps/authoring/store/parts/slice';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
// the authoring activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const AuthoringActivityRenderer = ({ activityModel, editMode, configEditorId, onSelectPart, onCopyPart, onConfigurePart, onCancelConfigurePart, onSaveConfigurePart, onPartChangePosition, notificationStream, }) => {
    var _a;
    const dispatch = useDispatch();
    const [isReady, setIsReady] = useState(false);
    const selectedPartId = useSelector(selectCurrentSelection);
    if (!activityModel.authoring || !activityModel.activityType) {
        console.warn('Bad Activity Data', activityModel);
        return null;
    }
    const ref = useRef(null);
    const elementProps = {
        id: `activity-${activityModel.id}`,
        ref,
        model: JSON.stringify(activityModel),
        editMode,
        style: {
            position: 'absolute',
            top: '65px',
            left: '300px',
            paddingRight: '300px',
            paddingBottom: '300px',
        },
        authoringContext: JSON.stringify({
            selectedPartId,
            configurePortalId: configEditorId,
        }),
    };
    const sendNotify = useCallback((type, payload) => {
        if (ref.current && ref.current.notify) {
            ref.current.notify(type, payload);
        }
    }, [ref]);
    useEffect(() => {
        // the "notificationStream" is a state based way to "push" stuff into the activity
        // from here it uses the notification system which is an event emitter because
        // these are web components and not in the same react context, and
        // in order to send via props as state we would need to stringify the object
        if (notificationStream === null || notificationStream === void 0 ? void 0 : notificationStream.stamp) {
            sendNotify(notificationStream.type, notificationStream.payload);
        }
    }, [notificationStream]);
    useEffect(() => {
        const customEventHandler = (e) => __awaiter(void 0, void 0, void 0, function* () {
            const target = e.target;
            if ((target === null || target === void 0 ? void 0 : target.id) === elementProps.id) {
                const { payload, continuation } = e.detail;
                let result = null;
                if (payload.eventName === 'selectPart' && onSelectPart) {
                    result = yield onSelectPart(payload.payload.id);
                }
                if (payload.eventName === 'copyPart' && onCopyPart) {
                    result = yield onCopyPart(payload.payload.copiedPart);
                }
                if (payload.eventName === 'configurePart' && onConfigurePart) {
                    result = yield onConfigurePart(payload.payload.part, payload.payload.context);
                }
                if (payload.eventName === 'saveConfigurePart' && onSaveConfigurePart) {
                    result = yield onSaveConfigurePart(payload.payload.partId);
                }
                if (payload.eventName === 'cancelConfigurePart' && onCancelConfigurePart) {
                    result = yield onCancelConfigurePart(payload.payload.partId);
                }
                // DEPRECATED
                if (payload.eventName === 'dragPart' && onPartChangePosition) {
                    result = yield onPartChangePosition(payload.payload.activityId, payload.payload.partId, payload.payload.dragData);
                }
                if (continuation) {
                    continuation(result);
                }
            }
        });
        // for now just do this, todo we need to setup events and listen
        document.addEventListener('customEvent', customEventHandler);
        const handleActivityEdit = (e) => __awaiter(void 0, void 0, void 0, function* () {
            const target = e.target;
            if ((target === null || target === void 0 ? void 0 : target.id) === elementProps.id) {
                const { model } = e.detail;
                /* console.log('AAR handleActivityEdit', { model }); */
                dispatch(saveActivity({ activity: model }));
                // why were we clearing the selection on edit?...
                // dispatch(setCurrentSelection({ selection: '' }));
                // dispatch(setRightPanelActiveTab({ rightPanelActiveTab: RightPanelTabs.SCREEN }));
            }
        });
        document.addEventListener('modelUpdated', handleActivityEdit);
        setIsReady(true);
        return () => {
            document.removeEventListener('customEvent', customEventHandler);
            document.removeEventListener('modelUpdated', handleActivityEdit);
        };
    }, []);
    return isReady
        ? React.createElement((_a = activityModel.activityType) === null || _a === void 0 ? void 0 : _a.authoring_element, elementProps, null)
        : null;
};
export default AuthoringActivityRenderer;
//# sourceMappingURL=AuthoringActivityRenderer.jsx.map