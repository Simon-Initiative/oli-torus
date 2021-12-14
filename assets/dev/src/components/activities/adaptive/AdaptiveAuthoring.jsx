var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { NotificationContext, NotificationType, subscribeToNotification, } from 'apps/delivery/components/NotificationContext';
import EventEmitter from 'events';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone } from 'utils/common';
import { AuthoringElement } from '../AuthoringElement';
import LayoutEditor from './components/authoring/LayoutEditor';
const Adaptive = (props) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    // we create this to be able to further send down notifcations that came from the parent notifier
    const [pusher, setPusher] = useState(new EventEmitter().setMaxListeners(50));
    useEffect(() => {
        if (!props.notify) {
            return;
        }
        const notificationsHandled = [
            NotificationType.CHECK_STARTED,
            NotificationType.CHECK_COMPLETE,
            NotificationType.CONTEXT_CHANGED,
            NotificationType.STATE_CHANGED,
            NotificationType.CONFIGURE,
            NotificationType.CONFIGURE_CANCEL,
            NotificationType.CONFIGURE_SAVE,
        ];
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (e) => {
                // for now we will just forward the notification to the context
                pusher.emit(notificationType.toString(), e);
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
    const [selectedPartId, setSelectedPartId] = useState('');
    const [configurePortalId, setConfigurePortalId] = useState('');
    const [parts, setParts] = useState(((_b = (_a = props.model) === null || _a === void 0 ? void 0 : _a.content) === null || _b === void 0 ? void 0 : _b.partsLayout) || []);
    // this effect keeps the local parts state in sync with the props
    useEffect(() => {
        var _a, _b;
        setParts(((_b = (_a = props.model) === null || _a === void 0 ? void 0 : _a.content) === null || _b === void 0 ? void 0 : _b.partsLayout) || []);
    }, [(_d = (_c = props.model) === null || _c === void 0 ? void 0 : _c.content) === null || _d === void 0 ? void 0 : _d.partsLayout]);
    // this effect sets the selection from the outside based on authoring context
    useEffect(() => {
        if (props.authoringContext) {
            /* console.log('[AdaptiveAuthoring] AuthoringContext: ', props.authoringContext); */
            setSelectedPartId(props.authoringContext.selectedPartId);
            setConfigurePortalId(props.authoringContext.configurePortalId || '');
        }
    }, [props.authoringContext]);
    const handleLayoutChange = useCallback((parts) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('Layout Change!', parts); */
        const modelClone = clone(props.model);
        modelClone.content.partsLayout = parts;
        props.onEdit(modelClone);
    }), [props.model]);
    const handlePartSelect = useCallback((partId) => __awaiter(void 0, void 0, void 0, function* () {
        if (!props.editMode) {
            return;
        }
        setSelectedPartId(partId);
        if (props.onCustomEvent) {
            const result = yield props.onCustomEvent('selectPart', { id: partId });
            /* console.log('got result from onSelect', result); */
        }
    }), [props.onCustomEvent, props.editMode, selectedPartId]);
    const handleCopyComponent = useCallback((selectedPart) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('AUTHOR PART COPY', { selectedPart }); */
        if (props.onCustomEvent) {
            const result = yield props.onCustomEvent('copyPart', { copiedPart: selectedPart });
        }
        //dispatch(setCopiedPart({ copiedPart: selectedPart }));
    }), [props.onCustomEvent]);
    const handleConfigurePart = useCallback((part, context) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('[AdaptiveAuthoring] PART CONFIGURE', { part, context }); */
        if (props.onCustomEvent) {
            const result = yield props.onCustomEvent('configurePart', {
                part,
                context,
            });
        }
    }), [props.onCustomEvent]);
    const handleCancelConfigurePart = useCallback((partId) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('AUTHOR PART CANCEL CONFIGURE', { partId }); */
        if (props.onCustomEvent) {
            const result = yield props.onCustomEvent('cancelConfigurePart', {
                partId,
            });
        }
    }), [props.onCustomEvent]);
    return (<NotificationContext.Provider value={pusher}>
      <LayoutEditor id={props.model.id || ''} hostRef={props.hostRef} width={((_f = (_e = props.model.content) === null || _e === void 0 ? void 0 : _e.custom) === null || _f === void 0 ? void 0 : _f.width) || 1000} height={((_h = (_g = props.model.content) === null || _g === void 0 ? void 0 : _g.custom) === null || _h === void 0 ? void 0 : _h.height) || 500} backgroundColor={((_k = (_j = props.model.content) === null || _j === void 0 ? void 0 : _j.custom) === null || _k === void 0 ? void 0 : _k.palette.backgroundColor) || '#fff'} selected={selectedPartId} parts={parts} onChange={handleLayoutChange} onCopyPart={handleCopyComponent} onConfigurePart={handleConfigurePart} onCancelConfigurePart={handleCancelConfigurePart} configurePortalId={configurePortalId} onSelect={handlePartSelect}/>
    </NotificationContext.Provider>);
};
export class AdaptiveAuthoring extends AuthoringElement {
    props() {
        const superProps = super.props();
        return Object.assign(Object.assign({}, superProps), { hostRef: this });
    }
    render(mountPoint, props) {
        ReactDOM.render(<Adaptive {...props}/>, mountPoint);
    }
}
// eslint-disable-next-line
const manifest = require('./manifest.json');
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
//# sourceMappingURL=AdaptiveAuthoring.jsx.map