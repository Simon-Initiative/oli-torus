/* eslint-disable react/prop-types */
import React, { useEffect, useRef } from 'react';

const WebComponent: React.FC<any> = (props) => {
    // TODO: build from configuration instead
    const wcEvents: any = {
        init: props.onInit,
        ready: props.onReady,
        save: props.onSave,
        submit: props.onSubmit,
    };

    const wcEventHandler = async (e: any) => {
        const handler = wcEvents[e.type];
        if (handler) {
            const { payload, callback } = e.detail;
            const result = await handler(payload);
            if (callback) {
                callback(result);
            }
        }
    };

    const ref = useRef(null);
    useEffect(() => {
        if (ref.current) {
            const wc = ref.current as any;
            Object.keys(wcEvents).forEach((eventName) => {
                wc.addEventListener(eventName, wcEventHandler);
            });
        }
        return () => {
            if (ref.current) {
                const wc = ref.current as any;
                Object.keys(wcEvents).forEach((eventName) => {
                    wc.removeEventListener(eventName, wcEventHandler);
                });
            }
        };
    }, [ref.current]);
    const webComponentProps = {
        ref,
        id: props.id,
        type: props.type,
        ...props,
        model: JSON.stringify(props.model),
        state: JSON.stringify(props.state),
    };

    const wcTagName = props.type;
    if (!wcTagName || !customElements.get(wcTagName)) {
        return React.createElement('div', {}, 'unknown');
    }

    return React.createElement(wcTagName, webComponentProps);
};

export default WebComponent;
