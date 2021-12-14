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
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseBool } from '../../../utils/common';
const Dropdown = (props) => {
    const [state, setState] = useState(Array.isArray(props.state) ? props.state : []);
    const [model, setModel] = useState(Array.isArray(props.model) ? props.model : {});
    const [ready, setReady] = useState(false);
    const id = props.id;
    const [enabled, setEnabled] = useState(true);
    const [selectedIndex, setSelectedIndex] = useState(-1);
    const [selectedItem, setSelectedItem] = useState('');
    const [cssClass, setCssClass] = useState('');
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        var _a;
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
                    key: 'customCssClass',
                    type: CapiVariableTypes.STRING,
                    value: dCssClass,
                },
                {
                    id: `selectedIndex`,
                    key: 'selectedIndex',
                    type: CapiVariableTypes.NUMBER,
                    value: selectedIndex,
                },
                {
                    id: `selectedItem`,
                    key: 'selectedItem',
                    type: CapiVariableTypes.STRING,
                    value: selectedItem,
                },
                {
                    id: `value`,
                    key: 'value',
                    type: CapiVariableTypes.STRING,
                    value: 'NULL',
                },
            ],
        });
        // result of init has a state snapshot with latest (init state applied)
        const currentStateSnapshot = initResult.snapshot;
        const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
        if (sEnabled !== undefined) {
            setEnabled(sEnabled);
        }
        const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
        if (sCssClass !== undefined) {
            setCssClass(sCssClass);
        }
        // TODO: value ??
        const sSelectedIndex = currentStateSnapshot[`stage.${id}.selectedIndex`];
        if (sSelectedIndex !== undefined && Number(sSelectedIndex) !== -1) {
            const stateSelection = Number(sSelectedIndex);
            setSelectedIndex(stateSelection);
            if (pModel.optionLabels) {
                setSelectedItem(pModel.optionLabels[stateSelection - 1]);
                setTimeout(() => {
                    saveState({
                        selectedIndex: stateSelection,
                        selectedItem: pModel.optionLabels[stateSelection - 1],
                        value: pModel.optionLabels[stateSelection - 1],
                        enabled,
                    });
                });
            }
        }
        const sSelectedItem = currentStateSnapshot[`stage.${id}.selectedItem`];
        if (sSelectedItem !== undefined && sSelectedItem !== '') {
            const selectionIndex = (_a = pModel.optionLabels) === null || _a === void 0 ? void 0 : _a.findIndex((str) => sSelectedItem.includes(str));
            setSelectedItem(sSelectedItem);
            setSelectedIndex(selectionIndex + 1);
            setTimeout(() => {
                saveState({
                    selectedIndex: selectionIndex + 1,
                    selectedItem: sSelectedItem,
                    value: sSelectedItem,
                    enabled,
                });
            });
        }
        //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
        if (initResult.context.mode === contexts.REVIEW) {
            setEnabled(false);
        }
        setReady(true);
    }), []);
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
    const { x, y, z, width, height, customCssClass, showLabel, label, prompt, optionLabels, palette, } = model;
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
    const dropdownContainerStyles = {
        width,
    };
    const dropDownStyle = {
        width: 'auto',
        height: 'auto',
    };
    if (!(showLabel && label)) {
        dropDownStyle.width = `${Number(width) - 10}px`;
    }
    if (showLabel && label && width) {
        //is this the best way to handle?
        //if lable is visible then need to set the maxWidth otherwise it gets out of the container
        dropDownStyle.maxWidth = `${Number(width * 0.63)}px`;
    }
    useEffect(() => {
        //TODO commenting for now. Need to revisit once state structure logic is in place
        //handleStateChange(state);
    }, [state]);
    const saveState = ({ selectedIndex, selectedItem, value, enabled, }) => {
        props.onSave({
            id: `${id}`,
            responses: [
                {
                    key: 'enabled',
                    type: CapiVariableTypes.BOOLEAN,
                    value: enabled,
                },
                {
                    key: 'selectedIndex',
                    type: CapiVariableTypes.NUMBER,
                    value: selectedIndex,
                },
                {
                    key: 'selectedItem',
                    type: CapiVariableTypes.STRING,
                    value: selectedItem,
                },
                {
                    key: 'value',
                    type: CapiVariableTypes.STRING,
                    value: value,
                },
            ],
        });
    };
    const handleChange = (event) => {
        const val = Number(event.target.value);
        // Update/set the value
        setSelectedIndex(val);
        saveState({
            selectedIndex: val,
            selectedItem: event.target.options[event.target.selectedIndex].text,
            value: event.target.options[event.target.selectedIndex].text,
            enabled,
        });
    };
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
                /* console.log(`${notificationType.toString()} notification handled [Dropdown]`, payload); */
                switch (notificationType) {
                    case NotificationType.CHECK_STARTED:
                        // nothing to do
                        break;
                    case NotificationType.CHECK_COMPLETE:
                        // nothing to do
                        // TODO: highlight incorrect?
                        break;
                    case NotificationType.STATE_CHANGED:
                        {
                            const { mutateChanges: changes } = payload;
                            const sSelectedIndex = changes[`stage.${id}.selectedIndex`];
                            if (sSelectedIndex !== undefined) {
                                const stateSelection = Number(sSelectedIndex);
                                if (selectedIndex !== stateSelection) {
                                    setSelectedIndex(stateSelection);
                                    setSelectedItem(optionLabels[stateSelection - 1]);
                                    setTimeout(() => {
                                        saveState({
                                            selectedIndex: stateSelection,
                                            selectedItem: optionLabels[stateSelection - 1],
                                            value: optionLabels[stateSelection - 1],
                                            enabled,
                                        });
                                    });
                                }
                            }
                            const sSelectedItem = changes[`stage.${id}.selectedItem`];
                            if (sSelectedItem !== undefined) {
                                if (selectedItem !== sSelectedItem) {
                                    const selectionIndex = optionLabels.findIndex((str) => sSelectedItem.includes(str));
                                    setSelectedItem(sSelectedItem);
                                    setSelectedIndex(selectionIndex + 1);
                                    setTimeout(() => {
                                        saveState({
                                            selectedIndex: selectionIndex + 1,
                                            selectedItem: sSelectedItem,
                                            value: sSelectedItem,
                                            enabled,
                                        });
                                    });
                                }
                            }
                            const sEnabled = changes[`stage.${id}.enabled`];
                            if (sEnabled !== undefined) {
                                setEnabled(parseBool(sEnabled));
                            }
                        }
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        {
                            const { initStateFacts: changes } = payload;
                            const sSelectedIndex = changes[`stage.${id}.selectedIndex`];
                            if (sSelectedIndex !== undefined) {
                                const stateSelection = Number(sSelectedIndex);
                                if (selectedIndex !== stateSelection) {
                                    setSelectedIndex(stateSelection);
                                    setSelectedItem(optionLabels[stateSelection - 1]);
                                    setTimeout(() => {
                                        saveState({
                                            selectedIndex: stateSelection,
                                            selectedItem: optionLabels[stateSelection - 1],
                                            value: optionLabels[stateSelection - 1],
                                            enabled,
                                        });
                                    });
                                }
                            }
                            const sSelectedItem = changes[`stage.${id}.selectedItem`];
                            if (sSelectedItem !== undefined) {
                                if (selectedItem !== sSelectedItem) {
                                    const selectionIndex = optionLabels.findIndex((str) => sSelectedItem.includes(str));
                                    setSelectedItem(sSelectedItem);
                                    setSelectedIndex(selectionIndex + 1);
                                    setTimeout(() => {
                                        saveState({
                                            selectedIndex: selectionIndex + 1,
                                            selectedItem: sSelectedItem,
                                            value: sSelectedItem,
                                            enabled,
                                        });
                                    });
                                }
                            }
                            const sEnabled = changes[`stage.${id}.enabled`];
                            if (sEnabled !== undefined) {
                                setEnabled(parseBool(sEnabled));
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
    }, [props.notify, optionLabels]);
    // Generate a list of options using optionLabels
    const dropdownOptions = () => {
        // use explicit Array() since we're using Elements
        const options = [];
        if (prompt) {
            // If a prompt exists and the selectedIndex is not set or is set to -1, set prompt as disabled first option
            options.push(<option key="-1" value="-1" style={{ display: 'none' }}>
          {prompt}
        </option>);
        }
        else if (!selectedIndex || selectedIndex === -1) {
            // If a prompt is blank and the selectedIndex is not set or is set to -1, set empty first option
            options.push(<option key="-1" value="-1" selected={true} style={{ display: 'none' }}></option>);
        }
        if (optionLabels) {
            for (let i = 0; i < optionLabels.length; i++) {
                // Set selected if selectedIndex equals current index
                options.push(<option key={i + 1} value={i + 1} selected={i + 1 === selectedIndex}>
            {optionLabels[i]}
          </option>);
            }
        }
        return options;
    };
    return ready ? (<div data-janus-type={tagName} className="dropdown-input" style={dropdownContainerStyles}>
      <label htmlFor={`${id}-select`}>{showLabel && label ? label : ''}</label>
      <select style={dropDownStyle} id={`${id}-select`} value={selectedIndex} className={'dropdown '} onChange={handleChange} disabled={!enabled}>
        {dropdownOptions()}
      </select>
    </div>) : null;
};
export const tagName = 'janus-dropdown';
export default Dropdown;
//# sourceMappingURL=Dropdown.jsx.map