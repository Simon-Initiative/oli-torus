/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { CapiVariable } from '../../../../adaptivity/capi';
import { defaultGlobalEnv, getEnvState, } from '../../../../adaptivity/scripting';
import { applyStateChange } from '../../store/features/adaptivity/actions/applyStateChange';
import { selectCurrentActivityTree } from '../../store/features/groups/selectors/deck';
import StateDisplay from './inspector/StateDisplay';
import { unflatten } from './inspector/utils';
// Inspector Placeholder
const Inspector = ({ currentActivity }) => {
    const dispatch = useDispatch();
    const [globalState, setGlobalState] = useState(null);
    const [sessionState, setSessionState] = useState({});
    const [variablesState, setVariablesState] = useState({});
    const [stageState, setStageState] = useState({});
    const [appState, setAppState] = useState({});
    const [autoApplyChanges, setAutoApplyChanges] = useState(false);
    const [changeOperations, setChangeOperations] = useState([]);
    // TODO: technically this tree concept only exists in the DECK layout
    // another layout like single activity or stacked might not have layers to deal with
    // so need to create some kind of generic layout method to get the needed info instead
    // well actually the preview tools might only apply to deck layout
    const currentActivityTree = useSelector(selectCurrentActivityTree);
    const getAppState = () => {
        const statePuff = unflatten(globalState);
        const appSlice = Object.assign({}, statePuff['app']);
        /* console.log('APP STATE PUFF', { statePuff, appSlice }); */
        return setAppState(appSlice);
    };
    const getSessionState = () => {
        const statePuff = unflatten(globalState);
        const sessionSlice = Object.assign({}, statePuff['session']);
        /* console.log('SESSION STATE PUFF', { statePuff, sessionSlice }); */
        return setSessionState(sessionSlice);
    };
    const getVariablesState = () => {
        const statePuff = unflatten(globalState);
        const variablesSlice = Object.assign({}, statePuff['variables']);
        /* console.log('VARIABLES STATE PUFF', { statePuff, variablesSlice }); */
        return setVariablesState(variablesSlice);
    };
    const getStageState = () => {
        const statePuff = unflatten(globalState);
        const stageSlice = currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.reduce((collect, activity) => {
            var _a;
            //A layer variable exist in state with owner screen Id as well as with it's child screen. So, we have to make sure that we only display the owner Id's variables in the inspector
            const activityVars = statePuff[`${activity.id}|stage`];
            let ownerVariables = {};
            if (activityVars) {
                ownerVariables = (_a = Object.keys(activityVars)) === null || _a === void 0 ? void 0 : _a.reduce((col, part) => {
                    const ownerActivity = currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.find((activity) => !!activity.content.partsLayout.find((p) => p.id === part));
                    if (ownerActivity.id === activity.id) {
                        const partVariables = statePuff[`${activity.id}|stage`];
                        const partCol = {};
                        partCol[part] = partVariables[part];
                        const next = Object.assign(Object.assign({}, col), partCol);
                        return next;
                    }
                    else {
                        return Object.assign({}, col);
                    }
                }, {});
            }
            if (ownerVariables) {
                const next = Object.assign(Object.assign({}, collect), ownerVariables);
                return next;
            }
            else {
                return Object.assign({}, collect);
            }
        }, {});
        /* console.log('STAGE STATE PUFF', { statePuff, stageSlice }); */
        return setStageState(stageSlice);
    };
    // change handler fires for every key, and there are often several at once
    const debounceStateChanges = useCallback(debounce(() => {
        const allState = getEnvState(defaultGlobalEnv);
        const globalStateAsVars = Object.keys(allState).reduce((collect, key) => {
            collect[key] = new CapiVariable({ key, value: allState[key] });
            return collect;
        }, {});
        setGlobalState(globalStateAsVars);
    }, 50), []);
    useEffect(() => {
        setAppState({});
        setStageState({});
        setSessionState({});
        setVariablesState({});
        debounceStateChanges();
        defaultGlobalEnv.addListener('change', debounceStateChanges);
        return () => {
            defaultGlobalEnv.removeListener('change', debounceStateChanges);
        };
    }, [currentActivityTree]);
    useEffect(() => {
        if (!globalState) {
            return;
        }
        getAppState();
        getSessionState();
        getVariablesState();
        getStageState();
    }, [globalState]);
    const handleValueChange = useCallback((changeOp) => {
        /* console.log('INSPECTOR TOP CHANGES', { changeOp, changeOperations }); */
        if (autoApplyChanges) {
            dispatch(applyStateChange({ operations: [changeOp] }));
        }
        else {
            setChangeOperations([...changeOperations, changeOp]);
        }
    }, [changeOperations]);
    const handleApplyChanges = useCallback((e) => {
        if (changeOperations.length === 0) {
            return;
        }
        dispatch(applyStateChange({ operations: changeOperations }));
        setChangeOperations([]);
    }, [changeOperations]);
    const handleCancelChanges = (e) => {
        debounceStateChanges();
        setChangeOperations([]);
    };
    const changeCount = changeOperations.length;
    const hasChanges = changeCount > 0;
    return (<div className="inspector">
      <div className="apply-changes btn-group-sm p-2" role="group" aria-label="Apply changes">
        <button disabled={!hasChanges} type="button" className="btn btn-secondary mr-1" onClick={handleCancelChanges}>
          Cancel
        </button>
        <button disabled={!hasChanges} type="button" className="btn btn-primary ml-1" onClick={handleApplyChanges}>
          Apply {hasChanges ? `(${changeCount})` : null}
        </button>
      </div>
      <div className="accordion">
        <StateDisplay label="App" state={appState} onChange={handleValueChange}/>
        <StateDisplay label="Session" state={sessionState} onChange={handleValueChange}/>
        <StateDisplay label="Variables" state={variablesState} onChange={handleValueChange}/>
        <StateDisplay label="Stage" state={stageState} onChange={handleValueChange}/>
      </div>
    </div>);
};
export default Inspector;
//# sourceMappingURL=Inspector.jsx.map