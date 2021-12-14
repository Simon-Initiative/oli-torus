var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import React, { useCallback, useEffect, useRef, useState } from 'react';
import Select2 from 'react-select2-wrapper';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { usePrevious } from '../../hooks/usePrevious';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const css = require('./FillBlanks.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const quill = require('./Quill.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const select2Styles = require('react-select2-wrapper/css/select2.css');
export const parseBool = (val) => {
    // cast value to number
    const num = +val;
    return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};
const FillBlanks = (props) => {
    const id = props.id;
    const [state, setState] = useState(Array.isArray(props.state) ? props.state : []);
    const [model, setModel] = useState(Array.isArray(props.model) ? props.model : []);
    const [localSnapshot, setLocalSnapshot] = useState({});
    const [stateChanged, setStateChanged] = useState(false);
    const [mutateState, setMutateState] = useState({});
    const { x = 0, y = 0, z = 0, width, height, content, elements, alternateCorrectDelimiter, } = model;
    const fibContainer = useRef(null);
    const [attempted, setAttempted] = useState(false);
    const [contentList, setContentList] = useState([]);
    const [elementValues, setElementValues] = useState([]);
    const [newElement, setNewElement] = useState();
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
    const prevElementValues = usePrevious(elementValues);
    const [enabled, setEnabled] = useState((model === null || model === void 0 ? void 0 : model.enabled) ? parseBool(model.enabled) : true);
    const [correct, setCorrect] = useState((model === null || model === void 0 ? void 0 : model.correct) ? parseBool(model.correct) : false);
    const [showCorrect, setShowCorrect] = useState((model === null || model === void 0 ? void 0 : model.showCorrect) ? parseBool(model.showCorrect) : false);
    const [showHints, setShowHints] = useState((model === null || model === void 0 ? void 0 : model.showHints) ? parseBool(model.showHints) : false);
    const [customCss, setCustomCss] = useState((model === null || model === void 0 ? void 0 : model.customCss) ? model.customCss : '');
    const [customCssClass, setCustomCssClass] = useState((model === null || model === void 0 ? void 0 : model.customCss) ? model.customCss : '');
    const [ready, setReady] = useState(false);
    const wrapperStyles = {
        /* position: 'absolute',
        top: y,
        left: x,
        width,
        zIndex: z, */
        height,
        borderRadius: '5px',
        fontFamily: 'revert',
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
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        var _a;
        const partResponses = (_a = pModel === null || pModel === void 0 ? void 0 : pModel.elements) === null || _a === void 0 ? void 0 : _a.map((el) => {
            var _a;
            const val = getElementValueByKey(el.key);
            const index = (_a = pModel === null || pModel === void 0 ? void 0 : pModel.elements) === null || _a === void 0 ? void 0 : _a.findIndex((o) => o.key === el.key);
            return [
                {
                    key: `Input ${index + 1}.Value`,
                    type: CapiVariableTypes.STRING,
                    value: val || '',
                },
                {
                    key: `Input ${index + 1}.Correct`,
                    type: CapiVariableTypes.BOOLEAN,
                    value: isCorrect(val, el.correct, el.alternateCorrect),
                },
                { key: `showCorrect`, type: CapiVariableTypes.BOOLEAN, value: pModel.showCorrect },
                { key: `showHints`, type: CapiVariableTypes.BOOLEAN, value: pModel.showHints },
            ];
        });
        const elementPartResponses = [].concat(...partResponses);
        const initResult = yield props.onInit({
            id,
            responses: [...elementPartResponses],
        });
        //customCss comes from model and it was assigning blank value to customCss variable on line #85. Once model is updated
        //need to assign the update values to the variable
        if (pModel === null || pModel === void 0 ? void 0 : pModel.customCss) {
            setCustomCss(pModel.customCss);
        }
        // result of init has a state snapshot with latest (init state applied)
        const currentStateSnapshot = initResult.snapshot;
        setLocalSnapshot(currentStateSnapshot);
        const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
        if (sEnabled) {
            setEnabled(parseBool(sEnabled));
        }
        const sShowCorrect = currentStateSnapshot[`stage.${id}.showCorrect`];
        if (sShowCorrect) {
            setShowCorrect(parseBool(sShowCorrect));
            pModel.elements.forEach((el) => {
                setTimeout(() => {
                    setNewElement({
                        key: el.key,
                        value: el.correct,
                    });
                });
            });
        }
        const sShowHints = currentStateSnapshot[`stage.${id}.showHints`];
        if (sShowHints) {
            setShowHints(parseBool(sShowHints));
        }
        const sCustomCss = currentStateSnapshot[`stage.${id}.customCss`];
        if (sCustomCss) {
            setCustomCss(sCustomCss);
        }
        const sCustomCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
        if (sEnabled) {
            setCustomCssClass(sCustomCssClass);
        }
        const sAttempted = currentStateSnapshot[`stage.${id}.attempted`];
        if (sAttempted) {
            setAttempted(parseBool(sAttempted));
        }
        //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
        if (initResult.context.mode === contexts.REVIEW) {
            setEnabled(false);
        }
        setReady(true);
    }), []);
    useEffect(() => {
        if (!ready) {
            return;
        }
        props.onReady({ id, responses: [] });
    }, [ready]);
    useEffect(() => {
        //if (elements?.length && state?.length) {
        if (elements === null || elements === void 0 ? void 0 : elements.length) {
            getStateSelections(localSnapshot);
            setContentList(buildContentList);
        }
    }, [elements, localSnapshot]);
    useEffect(() => {
        //if (elements?.length && state?.length) {
        if ((elements === null || elements === void 0 ? void 0 : elements.length) && stateChanged) {
            getStateSelections(mutateState);
            setContentList(buildContentList);
            setStateChanged(false);
        }
    }, [elements, stateChanged, mutateState]);
    useEffect(() => {
        // write to state when elementValues changes
        if (prevElementValues &&
            ((prevElementValues.length < 1 && elementValues.length > 0) ||
                // if previous element values contain values and the values don't match currently selected values
                (prevElementValues.length > 0 &&
                    !elementValues.every((val) => prevElementValues.includes(val))))) {
            saveElements();
            setContentList(buildContentList);
        }
    }, [elementValues]);
    useEffect(() => {
        // update `elementValues` when `newElement` is updated
        if (newElement) {
            setElementValues([newElement, ...elementValues.filter((obj) => newElement.key !== (obj === null || obj === void 0 ? void 0 : obj.key))]);
        }
    }, [newElement]);
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
                        const { mutateChanges: changes } = payload;
                        setStateChanged(true);
                        setMutateState(changes);
                        const sEnabled = changes[`stage.${id}.enabled`];
                        if (sEnabled) {
                            setEnabled(parseBool(sEnabled));
                        }
                        const sShowCorrect = changes[`stage.${id}.showCorrect`];
                        if (sShowCorrect) {
                            setShowCorrect(parseBool(sShowCorrect));
                            model.elements.forEach((el) => {
                                setTimeout(() => {
                                    setNewElement({
                                        key: el.key,
                                        value: el.correct,
                                    });
                                });
                            });
                        }
                        const showHints = changes[`stage.${id}.showHints`];
                        if (showHints) {
                            setShowHints(parseBool(showHints));
                        }
                        const sCustomCss = changes[`stage.${id}.customCss`];
                        if (sCustomCss) {
                            setCustomCss(sCustomCss);
                        }
                        const sCustomCssClass = changes[`stage.${id}.customCssClass`];
                        if (sCustomCssClass) {
                            setCustomCssClass(sCustomCssClass);
                        }
                        const sAttempted = changes[`stage.${id}.attempted`];
                        if (sAttempted) {
                            setAttempted(parseBool(sAttempted));
                        }
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        {
                            const { initStateFacts: changes } = payload;
                            const sEnabled = changes[`stage.${id}.enabled`];
                            if (sEnabled) {
                                setEnabled(parseBool(sEnabled));
                            }
                            const sShowCorrect = changes[`stage.${id}.showCorrect`];
                            if (sShowCorrect) {
                                setShowCorrect(parseBool(sShowCorrect));
                                model.elements.forEach((el) => {
                                    setTimeout(() => {
                                        setNewElement({
                                            key: el.key,
                                            value: el.correct,
                                        });
                                    });
                                });
                            }
                            const showHints = changes[`stage.${id}.showHints`];
                            if (showHints) {
                                setShowHints(parseBool(showHints));
                            }
                            const sCustomCss = changes[`stage.${id}.customCss`];
                            if (sCustomCss) {
                                setCustomCss(sCustomCss);
                            }
                            const sCustomCssClass = changes[`stage.${id}.customCssClass`];
                            if (sCustomCssClass) {
                                setCustomCssClass(sCustomCssClass);
                            }
                            const sAttempted = changes[`stage.${id}.attempted`];
                            if (sAttempted) {
                                setAttempted(parseBool(sAttempted));
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
    }, [props.notify, model]);
    const handleInput = (e) => {
        if (!e || typeof e === 'undefined')
            return;
        if (prevElementValues && prevElementValues.length > 0) {
            setAttempted(true);
        }
        setNewElement({
            key: e === null || e === void 0 ? void 0 : e.name,
            value: e === null || e === void 0 ? void 0 : e.value,
        });
    };
    const getElementValueByKey = (key) => {
        // get value from `elementValues` based on key
        if (!key || typeof key === 'undefined' || !(elementValues === null || elementValues === void 0 ? void 0 : elementValues.length))
            return;
        const val = elementValues === null || elementValues === void 0 ? void 0 : elementValues.find((obj) => obj.key === key);
        return typeof val !== 'undefined' && (val === null || val === void 0 ? void 0 : val.value) ? val.value.toString() : '';
    };
    // returns boolean
    const isCorrect = (submission, correct, alternateCorrect) => {
        if (!submission || !correct)
            return false;
        const correctArray = typeof alternateCorrect !== 'undefined'
            ? [correct, ...alternateCorrect.split(alternateCorrectDelimiter)]
            : [correct];
        return correctArray.includes(submission);
    };
    const saveElements = () => {
        if (!(elements === null || elements === void 0 ? void 0 : elements.length))
            return;
        const allCorrect = elements.every((element) => {
            const elVal = getElementValueByKey(element.key);
            return isCorrect(elVal, element.correct, element.alternateCorrect);
        });
        setCorrect(allCorrect);
        // set up responses array based on current selections/values of elements
        const partResponses = elements.map((el) => {
            const val = getElementValueByKey(el.key);
            const index = elements.findIndex((o) => o.key === el.key);
            return [
                {
                    key: `Input ${index + 1}.Value`,
                    type: CapiVariableTypes.STRING,
                    value: val,
                },
                {
                    key: `Input ${index + 1}.Correct`,
                    type: CapiVariableTypes.BOOLEAN,
                    value: isCorrect(val, el.correct, el.alternateCorrect),
                },
            ];
        });
        // save to state
        try {
            const elementPartResponses = [].concat(...partResponses);
            props.onSave({
                id: `${id}`,
                responses: [
                    ...elementPartResponses,
                    {
                        key: 'enabled',
                        type: CapiVariableTypes.BOOLEAN,
                        value: enabled,
                    },
                    {
                        key: 'showCorrect',
                        type: CapiVariableTypes.BOOLEAN,
                        value: showCorrect,
                    },
                    {
                        key: 'customCss',
                        type: CapiVariableTypes.STRING,
                        value: customCss,
                    },
                    {
                        key: 'customCssClass',
                        type: CapiVariableTypes.STRING,
                        value: customCssClass,
                    },
                    {
                        key: 'correct',
                        type: CapiVariableTypes.BOOLEAN,
                        value: allCorrect,
                    },
                    {
                        key: 'attempted',
                        type: CapiVariableTypes.BOOLEAN,
                        value: attempted,
                    },
                    {
                        key: 'showHints',
                        type: CapiVariableTypes.BOOLEAN,
                        value: showHints,
                    },
                ],
            });
        }
        catch (err) {
            console.log(err);
        }
    };
    const getStateSelections = (snapshot) => {
        var _a;
        if (!((_a = Object.keys(snapshot)) === null || _a === void 0 ? void 0 : _a.length) || !(elements === null || elements === void 0 ? void 0 : elements.length))
            return;
        // check for state vars that match elements keys and
        const interested = Object.keys(snapshot).filter((stateVar) => stateVar.indexOf(`stage.${id}.`) === 0);
        const stateValues = interested.map((stateVar) => {
            var _a;
            const sKey = stateVar;
            if ((sKey === null || sKey === void 0 ? void 0 : sKey.startsWith(`stage.${id}.Input `)) && (sKey === null || sKey === void 0 ? void 0 : sKey.endsWith('.Value'))) {
                const segments = sKey.split('.');
                const finalsKey = segments.slice(-2).join('.');
                // extract index from stateVar key
                const index = parseInt(finalsKey.replace(/[^0-9\\.]/g, ''), 10);
                // get key from `elements` based on 'Input [index].Value'
                const el = elements[index - 1];
                const val = (_a = snapshot[stateVar]) === null || _a === void 0 ? void 0 : _a.toString();
                if (el === null || el === void 0 ? void 0 : el.key)
                    return { key: el.key, value: val };
            }
            else {
                return false;
            }
        });
        // set new elementValues array
        setElementValues([
            ...stateValues,
            ...elementValues.filter((obj) => !stateValues.includes(obj === null || obj === void 0 ? void 0 : obj.key)),
        ]);
    };
    const buildContentList = content === null || content === void 0 ? void 0 : content.map((contentItem) => {
        if (!(elements === null || elements === void 0 ? void 0 : elements.length))
            return;
        const insertList = [];
        let insertEl;
        if (contentItem.insert) {
            // contentItem.insert is always a string
            insertList.push(<span dangerouslySetInnerHTML={{ __html: contentItem.insert }}/>);
        }
        else if (contentItem.dropdown) {
            // get correlating dropdown from `elements`
            insertEl = elements.find((elItem) => elItem.key === contentItem.dropdown);
            if (insertEl) {
                // build list of options for react-select
                const elVal = getElementValueByKey(insertEl.key);
                const optionsList = insertEl.options.map(({ value: text, key: id }) => ({ id, text }));
                const answerStatus = (showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)) ||
                    (showHints && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect))
                    ? 'correct'
                    : 'incorrect';
                insertList.push(<span className="dropdown-blot" tabIndex={-1}>
              <span className="dropdown-container" tabIndex={-1}>
                <Select2 className={`dropdown ${showCorrect || showHints ? answerStatus : ''}`} name={insertEl.key} data={optionsList} value={elVal} aria-label="Make a selection" options={{
                        dropdownParent: fibContainer.current,
                        minimumResultsForSearch: 10,
                        selectOnClose: false,
                    }} onChange={(e) => handleInput(e.currentTarget)} disabled={!enabled}/>
              </span>
            </span>);
            }
        }
        else if (contentItem['text-input']) {
            // get correlating inputText from `elements`
            insertEl = elements.find((elItem) => {
                return elItem.key === contentItem['text-input'];
            });
            if (insertEl) {
                const elVal = getElementValueByKey(insertEl.key);
                const answerStatus = (showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)) ||
                    (showHints && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect))
                    ? 'correct'
                    : 'incorrect';
                insertList.push(<span className="text-input-blot">
              <span className={`text-input-container ${showCorrect || showHints ? answerStatus : ''}`} tabIndex={-1}>
                <input name={insertEl.key} className={`text-input ${!enabled ? 'disabled' : ''} ${showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)
                        ? 'correct'
                        : ''}`} type="text" value={elVal} onChange={(e) => handleInput(e.currentTarget)} disabled={!enabled}/>
              </span>
            </span>);
            }
        }
        return insertList;
    });
    return (<div data-janus-type={tagName} style={wrapperStyles} className={`fib-container`} ref={fibContainer}>
      <style type="text/css">@import url(/css/janus_fill_blanks_delivery.css);</style>
      <style type="text/css">{`${customCss}`};</style>
      <div className="scene">
        <div className="app">
          <div className="editor ql-container ql-snow ql-disabled">
            <div className="ql-editor" data-gramm="false" contentEditable="false" suppressContentEditableWarning={true}>
              <p>{contentList}</p>
            </div>
          </div>
        </div>
      </div>
    </div>);
};
export const tagName = 'janus-fill-blanks';
export const watchedProps = ['model', 'id', 'state', 'type'];
export default FillBlanks;
//# sourceMappingURL=FillBlanks.jsx.map