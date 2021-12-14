var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { findReferencedActivitiesInConditions } from 'adaptivity/rules-engine';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import debounce from 'lodash/debounce';
import isEqual from 'lodash/isEqual';
import React, { useCallback, useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { selectCurrentRule } from '../../../authoring/store/app/slice';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { findInSequence, getIsBank, getIsLayer, } from '../../../delivery/store/features/groups/actions/sequence';
import { createFeedback } from '../../store/activities/actions/createFeedback';
import ActionFeedbackEditor from './ActionFeedbackEditor';
import ActionMutateEditor from './ActionMutateEditor';
import ActionNavigationEditor from './ActionNavigationEditor';
import ConditionsBlockEditor from './ConditionsBlockEditor';
export const AdaptivityEditor = () => {
    var _a, _b, _c, _d, _e;
    const dispatch = useDispatch();
    const currentRule = useSelector(selectCurrentRule);
    const currentActivity = useSelector(selectCurrentActivity);
    const sequence = useSelector(selectSequence);
    const isLayer = getIsLayer();
    const isBank = getIsBank();
    let sequenceTypeLabel = '';
    if (isLayer) {
        sequenceTypeLabel = 'layer';
    }
    else if (isBank) {
        sequenceTypeLabel = 'question bank';
    }
    const [isDirty, setIsDirty] = useState(false);
    const [isDisabled, setIsDisabled] = useState(!!(currentRule === null || currentRule === void 0 ? void 0 : currentRule.disabled));
    const [actions, setActions] = useState(((_b = (_a = currentRule === null || currentRule === void 0 ? void 0 : currentRule.event) === null || _a === void 0 ? void 0 : _a.params) === null || _b === void 0 ? void 0 : _b.actions) || []);
    const [conditions, setConditions] = useState(((_c = currentRule === null || currentRule === void 0 ? void 0 : currentRule.conditions) === null || _c === void 0 ? void 0 : _c.all) || ((_d = currentRule === null || currentRule === void 0 ? void 0 : currentRule.conditions) === null || _d === void 0 ? void 0 : _d.any) || []);
    const [rootConditionIsAll, setRootConditionIsAll] = useState(!!((_e = currentRule === null || currentRule === void 0 ? void 0 : currentRule.conditions) === null || _e === void 0 ? void 0 : _e.all));
    const hasFeedback = actions.find((action) => action.type === 'feedback');
    const hasNavigation = actions.find((action) => action.type === 'navigation');
    useEffect(() => {
        var _a, _b, _c, _d, _e;
        if (!currentRule)
            return;
        setIsDisabled(currentRule.disabled);
        setActions(((_b = (_a = currentRule.event) === null || _a === void 0 ? void 0 : _a.params) === null || _b === void 0 ? void 0 : _b.actions) || []);
        setConditions(((_c = currentRule.conditions) === null || _c === void 0 ? void 0 : _c.all) || ((_d = currentRule.conditions) === null || _d === void 0 ? void 0 : _d.any) || []);
        setRootConditionIsAll(!!((_e = currentRule.conditions) === null || _e === void 0 ? void 0 : _e.all));
    }, [currentRule]);
    useEffect(() => {
        if (!isDirty) {
            return;
        }
        const updatedRule = {
            id: currentRule.id,
            name: currentRule.name,
            additionalScore: currentRule.additionalScore || 0,
            priority: currentRule.priority || 1,
            forceProgress: !!currentRule.forceProgress,
            correct: currentRule.correct,
            default: currentRule.default,
            disabled: currentRule.disabled,
            conditions: {
                [rootConditionIsAll ? 'all' : 'any']: conditions,
            },
            event: Object.assign(Object.assign({}, currentRule.event), { type: currentRule.event.type || `${currentRule.id}.${currentRule.name}`, params: {
                    actions,
                } }),
        };
        setIsDirty(false);
        handleRuleChange(updatedRule);
    }, [isDirty]);
    const handleRuleChange = (rule) => {
        const existing = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.authoring.rules.find((r) => r.id === rule.id);
        const diff = JSON.stringify(rule) !== JSON.stringify(existing);
        /* console.log('RULE CHANGE: ', {
          rule,
          existing,
          diff,
        }); */
        if (!existing) {
            console.warn("rule not found, shouldn't happen!!!");
            return;
        }
        if (diff) {
            const activityClone = clone(currentActivity);
            const rulesClone = [...currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.authoring.rules];
            rulesClone[currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.authoring.rules.indexOf(existing)] = rule;
            activityClone.authoring.rules = rulesClone;
            // due to the way this works technically if we are *deleting" a condition with an external reference
            // then it will *not* be removed here, but it will be removed the next time the lesson is opened in the editor
            const conditionRefs = findReferencedActivitiesInConditions(rule.conditions.any || rule.conditions.all);
            if (conditionRefs.length > 0) {
                if (!activityClone.authoring.activitiesRequiredForEvaluation) {
                    activityClone.authoring.activitiesRequiredForEvaluation = [];
                }
                // need to find the resourceId based on the sequenceId that is referenced
                const resourceIds = conditionRefs
                    .map((conditionRef) => {
                    const sequenceItem = findInSequence(sequence, conditionRef);
                    if (sequenceItem) {
                        return sequenceItem.resourceId;
                    }
                    else {
                        console.warn(`[handleRuleChange] could not find referenced activity ${conditionRef} in sequence`, sequence);
                    }
                })
                    .filter((id) => id);
                const current = activityClone.authoring.activitiesRequiredForEvaluation;
                activityClone.authoring.activitiesRequiredForEvaluation = Array.from(new Set([...current, ...resourceIds]));
                /* console.log('[handleRuleChange] adding activities to required for evaluation', {
                  activityClone,
                  rule,
                }); */
            }
            dispatch(saveActivity({ activity: activityClone }));
        }
    };
    const notifyTime = 250;
    const debounceNotifyChanges = useCallback(debounce(() => {
        setIsDirty(true);
    }, notifyTime, { leading: false }), []);
    const handleConditionsEditorChange = (updatedConditionsBlock) => {
        /* console.log('CONDITION ED: ', updatedConditionsBlock); */
        const conds = updatedConditionsBlock.all || updatedConditionsBlock.any || [];
        const updatedIsAll = !!updatedConditionsBlock.all;
        const rootChanged = updatedIsAll !== rootConditionIsAll;
        const condsChanged = !isEqual(conditions, conds);
        if (!rootChanged && !condsChanged) {
            // nothing changed
            return;
        }
        setRootConditionIsAll(updatedIsAll);
        setConditions(conds);
        debounceNotifyChanges();
    };
    const getActionEditor = (action, index) => {
        switch (action.type) {
            case 'feedback':
                return (<ActionFeedbackEditor key={index} action={action} onChange={(changes) => {
                        handleActionChange(action, changes);
                    }} onDelete={handleDeleteAction}/>);
            case 'navigation':
                return (<ActionNavigationEditor key={index} action={action} onChange={(changes) => {
                        handleActionChange(action, changes);
                    }} allowDelete={!currentRule.correct} onDelete={handleDeleteAction}/>);
            case 'mutateState':
                return (<ActionMutateEditor key={index} action={action} onChange={(changes) => {
                        handleActionChange(action, changes);
                    }} onDelete={handleDeleteAction}/>);
        }
    };
    const handleAddAction = (actionType) => __awaiter(void 0, void 0, void 0, function* () {
        let newAction;
        switch (actionType) {
            case 'feedback':
                const result = yield dispatch(createFeedback({}));
                newAction = result.payload;
                break;
            case 'navigation':
                newAction = {
                    type: 'navigation',
                    params: {
                        target: 'next',
                    },
                };
                break;
            case 'mutateState':
                newAction = {
                    type: 'mutateState',
                    params: {
                        operator: '=',
                        target: 'stage.',
                        targetType: CapiVariableTypes.STRING,
                        value: undefined,
                    },
                };
                break;
        }
        if (newAction) {
            setActions([...actions, newAction]);
            debounceNotifyChanges();
        }
    });
    const handleActionChange = (action, changes) => __awaiter(void 0, void 0, void 0, function* () {
        const updated = Object.assign(Object.assign({}, action), { params: Object.assign(Object.assign({}, action.params), changes) });
        const actionIndex = actions.indexOf(action);
        /* console.log('action changed', { action, changes, actionIndex }); */
        if (actionIndex !== -1) {
            const cloneActions = [...actions];
            cloneActions[actionIndex] = updated;
            setActions(cloneActions);
            debounceNotifyChanges();
        }
    });
    const handleDeleteAction = (action) => __awaiter(void 0, void 0, void 0, function* () {
        // TODO: get rid of orphaned feedback ensembles!
        const temp = actions.filter((a) => a !== action);
        setActions(temp);
        debounceNotifyChanges();
    });
    return (<div className="aa-adaptivity-editor">
      {/* No Conditions */}
      {currentRule === undefined && (<div className="text-center border rounded">
          <div className="card-body">Please select a sequence item</div>
        </div>)}

      {currentRule && (isLayer || isBank) && (<div className="text-center border rounded">
          <div className="card-body">
            {`This sequence item is a ${sequenceTypeLabel} and does not support adaptivity`}
          </div>
        </div>)}

      {/* Has Conditions */}
      {currentRule && !isLayer && !isBank && (<>
          {!(currentRule.default && !currentRule.correct) && (<ConditionsBlockEditor id="root" type={rootConditionIsAll ? 'all' : 'any'} rootConditions={conditions} onChange={handleConditionsEditorChange} index={-1}/>)}
          <p className={`${currentRule.default && !currentRule.correct ? '' : 'mt-3'} mb-0`}>
            Perform the following actions:
          </p>
          <div className="aa-actions pt-3 mt-2 d-flex w-100">
            <OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  New Action
                </Tooltip>}>
              <button className="dropdown-toggle aa-add-button btn btn-primary btn-sm mr-3" type="button" id={`adaptive-editor-add-context-trigger`} data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" onClick={() => {
                $(`#adaptive-editor-add-context-trigger`).dropdown('toggle');
            }}>
                <i className="fa fa-plus"/>
              </button>
            </OverlayTrigger>
            <div id={`adaptive-editor-add-context-menu`} className="dropdown-menu" aria-labelledby={`adaptive-editor-add-context-trigger`}>
              {!hasFeedback && (<button className="dropdown-item" onClick={() => handleAddAction('feedback')}>
                  <i className="fa fa-comment mr-2"/> Show Feedback
                </button>)}
              {!hasNavigation && (<button className="dropdown-item" onClick={() => handleAddAction('navigation')}>
                  <i className="fa fa-compass mr-2"/> Navigate To
                </button>)}
              <button className="dropdown-item" onClick={() => handleAddAction('mutateState')}>
                <i className="fa fa-crosshairs mr-2"/> Mutate State
              </button>
            </div>
            <div className="d-flex flex-column w-100">
              {actions.length === 0 && (<div className="text-danger">No actions. This rule will not do anything.</div>)}
              {actions.length > 0 &&
                actions.map((action, index) => getActionEditor(action, index))}
            </div>
          </div>
        </>)}
    </div>);
};
//# sourceMappingURL=AdaptivityEditor.jsx.map