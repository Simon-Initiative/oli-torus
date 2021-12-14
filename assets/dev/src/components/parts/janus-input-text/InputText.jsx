var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseBool } from '../../../utils/common';
const InputText = (props) => {
    const [state, setState] = useState(Array.isArray(props.state) ? props.state : []);
    const [model, setModel] = useState(typeof props.model === 'object' ? props.model : {});
    const [ready, setReady] = useState(false);
    const id = props.id;
    const [enabled, setEnabled] = useState(true);
    const [cssClass, setCssClass] = useState('');
    const [text, setText] = useState('');
    //need to save the textLength
    const saveTextLength = (sText) => {
        props.onSave({
            id,
            responses: [
                {
                    key: 'textLength',
                    type: CapiVariableTypes.NUMBER,
                    value: sText.length,
                },
            ],
        });
    };
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        // set defaults
        const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
        setEnabled(dEnabled);
        const dCssClass = pModel.customCssClass || '';
        setCssClass(dCssClass);
        const dText = pModel.text || '';
        setText(dText);
        const initResult = yield props.onInit({
            id,
            responses: [
                {
                    key: 'enabled',
                    type: CapiVariableTypes.BOOLEAN,
                    value: dEnabled,
                },
                {
                    key: 'customCssClass',
                    type: CapiVariableTypes.STRING,
                    value: dCssClass,
                },
                {
                    key: 'text',
                    type: CapiVariableTypes.STRING,
                    value: dText,
                },
                {
                    key: 'textLength',
                    type: CapiVariableTypes.NUMBER,
                    value: dText.length,
                },
            ],
        });
        // result of init has a state snapshot with latest (init state applied)
        const currentStateSnapshot = initResult.snapshot;
        const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
        if (sEnabled !== undefined) {
            setEnabled(parseBool(sEnabled));
        }
        const sText = currentStateSnapshot[`stage.${id}.text`];
        if (sText !== undefined) {
            setText(sText);
            saveTextLength(sText);
        }
        const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
        if (sCssClass !== undefined) {
            setCssClass(sCssClass);
        }
        //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
        if (initResult.context.mode === contexts.REVIEW) {
            setEnabled(false);
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
                /* console.log(`${notificationType.toString()} notification handled [InputText]`, payload); */
                switch (notificationType) {
                    case NotificationType.CHECK_STARTED:
                        // nothing to do
                        break;
                    case NotificationType.CHECK_COMPLETE:
                        // nothing to do... change color if wrong?
                        break;
                    case NotificationType.STATE_CHANGED:
                        {
                            const { mutateChanges: changes } = payload;
                            const sEnabled = changes[`stage.${id}.enabled`];
                            if (sEnabled !== undefined) {
                                setEnabled(parseBool(sEnabled));
                            }
                            const sText = changes[`stage.${id}.text`];
                            if (sText !== undefined) {
                                setText(sText);
                                saveTextLength(sText);
                            }
                            const sCssClass = changes[`stage.${id}.customCssClass`];
                            if (sCssClass !== undefined) {
                                setCssClass(sCssClass);
                            }
                        }
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        {
                            const { initStateFacts } = payload;
                            const sEnabled = initStateFacts[`stage.${id}.enabled`];
                            if (sEnabled !== undefined) {
                                setEnabled(parseBool(sEnabled));
                            }
                            const sText = initStateFacts[`stage.${id}.text`];
                            if (sText !== undefined) {
                                setText(sText.toString());
                                saveTextLength(sText.toString());
                            }
                            const sCssClass = initStateFacts[`stage.${id}.customCssClass`];
                            if (sCssClass !== undefined) {
                                setCssClass(sCssClass);
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
    const { x, y, z, width, height, showLabel, label, prompt, fontSize } = model;
    const styles = {
        position: 'absolute',
        top: y,
        left: x,
        width,
        height,
        zIndex: z,
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
    const saveInputText = (val) => {
        props.onSave({
            id,
            responses: [
                {
                    key: 'text',
                    type: CapiVariableTypes.STRING,
                    value: val,
                },
                {
                    key: 'textLength',
                    type: CapiVariableTypes.NUMBER,
                    value: val.length,
                },
            ],
        });
    };
    const handleOnChange = (event) => {
        const el = event.target;
        const val = el.value;
        // Update/set the value
        setText(val);
        // Wait until user has stopped typing to save the new value
        debounceInputText(val);
    };
    const debounceWaitTime = 250;
    const debounceInputText = useCallback(debounce((val) => saveInputText(val), debounceWaitTime), []);
    return ready ? (<div data-janus-type={tagName} className={`short-text-input`} style={{ width: '100%' }}>
      <label htmlFor={`${id}-short-text-input`}>
        {showLabel && label ? label : <span>&nbsp;</span>}
      </label>
      <input name="janus-input-text" id={`${id}-short-text-input`} type="text" placeholder={prompt} onChange={handleOnChange} disabled={!enabled} value={text} style={{ width: '100%', fontSize }}/>
    </div>) : null;
};
export const tagName = 'janus-input-text';
export default InputText;
//# sourceMappingURL=InputText.jsx.map