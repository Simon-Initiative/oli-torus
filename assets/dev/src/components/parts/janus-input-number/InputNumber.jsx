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
import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseBool } from '../../../utils/common';
import './InputNumber.scss';
const InputNumber = (props) => {
    const [state, setState] = useState(Array.isArray(props.state) ? props.state : []);
    const [model, setModel] = useState(Array.isArray(props.model) ? props.model : {});
    const [ready, setReady] = useState(false);
    const id = props.id;
    const [inputNumberValue, setInputNumberValue] = useState('');
    const [enabled, setEnabled] = useState(true);
    const [cssClass, setCssClass] = useState('');
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        // set defaults
        const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
        setEnabled(dEnabled);
        const dCssClass = pModel.customCssClass || '';
        setCssClass(dCssClass);
        const initResult = yield props.onInit({
            id,
            responses: [
                {
                    key: 'enabled',
                    type: CapiVariableTypes.BOOLEAN,
                    value: dEnabled,
                },
                {
                    key: 'value',
                    type: CapiVariableTypes.NUMBER,
                    value: '',
                },
                {
                    key: 'customCssClass',
                    type: CapiVariableTypes.STRING,
                    value: dCssClass,
                },
            ],
        });
        // result of init has a state snapshot with latest (init state applied)
        const currentStateSnapshot = initResult.snapshot;
        const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
        if (sEnabled !== undefined) {
            setEnabled(parseBool(sEnabled));
        }
        const sValue = currentStateSnapshot[`stage.${id}.value`];
        if (sValue !== undefined) {
            setInputNumberValue(sValue);
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
                /* console.log(`${notificationType.toString()} notification handled [InputNumber]`, payload); */
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
                            const sEnabled = changes[`stage.${id}.enabled`];
                            if (sEnabled !== undefined) {
                                setEnabled(parseBool(sEnabled));
                            }
                            const sValue = changes[`stage.${id}.value`];
                            if (sValue !== undefined) {
                                setInputNumberValue(sValue);
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
                            const sValue = initStateFacts[`stage.${id}.value`];
                            if (sValue !== undefined) {
                                setInputNumberValue(sValue);
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
    const { x, y, z, width, height, minValue, maxValue, customCssClass, unitsLabel, label, showLabel, showIncrementArrows, prompt = '', } = model;
    const inputNumberDivStyles = {
        top: y,
        left: x,
        zIndex: z,
        width,
    };
    const inputNumberCompStyles = {
        width: '100%',
    };
    useEffect(() => {
        const styleChanges = {};
        if (width !== undefined) {
            styleChanges.width = { value: width };
        }
        props.onResize({ id: `${id}`, settings: styleChanges });
    }, [width]);
    const debouncetime = 300;
    const debounceSave = useCallback(debounce((val) => {
        saveInputText(val);
    }, debouncetime), []);
    const saveInputText = (val) => {
        props.onSave({
            id: `${id}`,
            responses: [
                {
                    key: 'value',
                    type: CapiVariableTypes.NUMBER,
                    value: val,
                },
            ],
        });
    };
    const handleOnChange = (event) => {
        const val = event.target.value;
        setInputNumberValue(val);
    };
    useEffect(() => {
        let val = isNaN(parseFloat(String(inputNumberValue)))
            ? ''
            : parseFloat(String(inputNumberValue));
        if (minValue !== maxValue && val !== '') {
            val = !isNaN(maxValue) ? Math.min(val, maxValue) : val;
            val = !isNaN(minValue) ? Math.max(val, minValue) : val;
        }
        if (val !== inputNumberValue) {
            setInputNumberValue(val);
        }
        else {
            debounceSave(val);
        }
    }, [inputNumberValue]);
    return ready ? (<div data-janus-type={tagName} style={inputNumberDivStyles} className={`number-input`}>
      {showLabel && (<React.Fragment>
          <label htmlFor={`${id}-number-input`} className="inputNumberLabel">
            {label.length > 0 ? label : ''}
          </label>
          <br />
        </React.Fragment>)}
      <input type="number" disabled={!enabled} onChange={handleOnChange} id={`${id}-number-input`} min={minValue} max={maxValue} placeholder={prompt} className={`${showIncrementArrows ? '' : 'hideIncrementArrows'}`} style={inputNumberCompStyles} value={inputNumberValue}/>
      {unitsLabel && <span className="unitsLabel">{unitsLabel}</span>}
    </div>) : null;
};
export const tagName = 'janus-input-number';
export default InputNumber;
//# sourceMappingURL=InputNumber.jsx.map