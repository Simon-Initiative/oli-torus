import {
  findReferencedActivitiesInActions,
  findReferencedActivitiesInConditions,
  getReferencedKeysInActions,
  getReferencedKeysInConditions,
} from 'adaptivity/rules-engine';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import debounce from 'lodash/debounce';
import isEqual from 'lodash/isEqual';
import React, { useCallback, useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip, Dropdown } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { selectCurrentRule } from '../../../authoring/store/app/slice';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import {
  findInSequence,
  getIsBank,
  getIsLayer,
} from '../../../delivery/store/features/groups/actions/sequence';
import { createFeedback } from '../../store/activities/actions/createFeedback';
import ActionFeedbackEditor from './ActionFeedbackEditor';
import ActionMutateEditor from './ActionMutateEditor';
import ActionNavigationEditor from './ActionNavigationEditor';
import ConditionsBlockEditor from './ConditionsBlockEditor';
import uniq from 'lodash/uniq';
import flatten from 'lodash/flatten';
export interface AdaptivityEditorProps {
  content?: any;
}

export type ActionType = 'navigation' | 'mutateState' | 'feedback';

export const AdaptivityEditor: React.FC<AdaptivityEditorProps> = () => {
  const dispatch = useDispatch();
  const currentRule = useSelector(selectCurrentRule);
  const currentActivity = useSelector(selectCurrentActivity);
  const sequence = useSelector(selectSequence);
  const isLayer = getIsLayer();
  const isBank = getIsBank();
  let sequenceTypeLabel = '';
  if (isLayer) {
    sequenceTypeLabel = 'layer';
  } else if (isBank) {
    sequenceTypeLabel = 'question bank';
  }

  const [isDirty, setIsDirty] = useState(false);
  const [isDisabled, setIsDisabled] = useState(!!currentRule?.disabled);
  const [actions, setActions] = useState(currentRule?.event?.params?.actions || []);
  const [conditions, setConditions] = useState<any>(
    currentRule?.conditions?.all || currentRule?.conditions?.any || [],
  );
  const [rootConditionIsAll, setRootConditionIsAll] = useState<boolean>(
    !!currentRule?.conditions?.all,
  );
  const hasFeedback = actions.find((action: any) => action.type === 'feedback');
  const hasNavigation = actions.find((action: any) => action.type === 'navigation');

  useEffect(() => {
    if (!currentRule) return;
    setIsDisabled(currentRule.disabled);
    setActions(currentRule.event?.params?.actions || []);
    setConditions(currentRule.conditions?.all || currentRule.conditions?.any || []);
    setRootConditionIsAll(!!currentRule.conditions?.all);
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
      event: {
        ...currentRule.event,
        type: currentRule.event.type || `${currentRule.id}.${currentRule.name}`,
        params: {
          actions,
        },
      },
    };
    setIsDirty(false);
    handleRuleChange(updatedRule);
  }, [isDirty]);

  const handleRuleChange = (rule: any) => {
    const existing = currentActivity?.authoring?.rules?.find((r: any) => r.id === rule.id);
    const diff = JSON.stringify(rule) !== JSON.stringify(existing);
    /*console.log('RULE CHANGE: ', {
      rule,
      existing,
      diff,
    });*/
    if (!existing) {
      console.warn("rule not found, shouldn't happen!!!");
      return;
    }
    if (diff && currentActivity?.authoring?.rules) {
      const activityClone = clone(currentActivity);
      const rulesClone = currentActivity ? [...currentActivity.authoring.rules] : [];
      rulesClone[currentActivity?.authoring.rules.indexOf(existing)] = rule;
      activityClone.authoring.rules = rulesClone;
      // due to the way this works technically if we are *deleting" a condition with an external reference
      // then it will *not* be removed here, but it will be removed the next time the lesson is opened in the editor
      const conditionRefs = findReferencedActivitiesInConditions(
        rule.conditions.any || rule.conditions.all,
      );
      const variableRefsInConditions = getReferencedKeysInConditions(
        rule.conditions.any || rule.conditions.all,
      );

      const actions = rule?.event?.params?.actions || [];
      const actionsRefs = findReferencedActivitiesInActions(actions);
      const variableRefsInActions = getReferencedKeysInActions(actions);

      if (!activityClone.authoring.variablesRequiredForEvaluation) {
        activityClone.authoring.variablesRequiredForEvaluation = [];
      }

      const concatVars = [...variableRefsInConditions, ...variableRefsInActions];

      activityClone.authoring.variablesRequiredForEvaluation.push(concatVars);
      // make unique
      activityClone.authoring.variablesRequiredForEvaluation = uniq(
        flatten([...new Set(activityClone.authoring.variablesRequiredForEvaluation)]),
      );

      if (!activityClone.authoring.activitiesRequiredForEvaluation) {
        activityClone.authoring.activitiesRequiredForEvaluation = [];
      }

      // finally need to add to the required activities any variables that are required but inherited from the sequence
      const treeRefs = activityClone.authoring.variablesRequiredForEvaluation
        .map((key: string) => {
          // find the key in the authoring.parts
          if (key.indexOf('stage.') === 0) {
            const [, componentId] = key.split('.');
            const partDef = activityClone.authoring.parts.find(
              (part: any) => part.id === componentId,
            );
            if (partDef && partDef.inherited) {
              return partDef.owner;
            }
          }
        })
        .filter((key: string) => key);

      const resourceIds = [...actionsRefs, ...conditionRefs, ...treeRefs]
        .map((ref: any) => {
          const sequenceItem = findInSequence(sequence, ref);
          if (sequenceItem) {
            return sequenceItem.resourceId;
          } else {
            console.warn(
              `[handleActionChange] could not find referenced activity ${ref} in sequence`,
              sequence,
            );
          }
        })
        .filter((id) => id) as number[];
      const current = activityClone.authoring.activitiesRequiredForEvaluation;
      activityClone.authoring.activitiesRequiredForEvaluation = Array.from(
        new Set([...current, ...resourceIds]),
      );
      /*console.log('[handleRuleChange] adding activities to required for evaluation', {
        activityClone,
        rule,
      });*/

      dispatch(saveActivity({ activity: activityClone, undoable: true, immediate: true }));
      // setTimeout(() => dispatch(setCurrentRule({ currentRule: rule })));
    }
  };

  const notifyTime = 250;
  const debounceNotifyChanges = useCallback(
    debounce(
      () => {
        setIsDirty(true);
      },
      notifyTime,
      { leading: false },
    ),
    [],
  );

  const handleConditionsEditorChange = (updatedConditionsBlock: any) => {
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
  const getActionEditor = (action: any, index: number) => {
    switch (action.type as ActionType) {
      case 'feedback':
        return (
          <ActionFeedbackEditor
            key={index}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
            onDelete={handleDeleteAction}
          />
        );
      case 'navigation':
        return (
          <ActionNavigationEditor
            key={index}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
            allowDelete={!currentRule.correct}
            onDelete={handleDeleteAction}
          />
        );
      case 'mutateState':
        return (
          <ActionMutateEditor
            key={index}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
            onDelete={handleDeleteAction}
          />
        );
    }
  };

  const handleAddAction = async (actionType: ActionType) => {
    let newAction;
    switch (actionType) {
      case 'feedback':
        const result = await dispatch(createFeedback({}));
        newAction = (result as any).payload;
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
  };

  const handleActionChange = async (action: any, changes: any) => {
    const updated = { ...action, params: { ...action.params, ...changes } };

    const actionIndex = actions.indexOf(action);

    if (actionIndex !== -1) {
      const cloneActions = [...actions];
      cloneActions[actionIndex] = updated;
      setActions(cloneActions);
      debounceNotifyChanges();
    }
  };

  const handleDeleteAction = async (action: any) => {
    // TODO: get rid of orphaned feedback ensembles!
    const temp = actions.filter((a: any) => a !== action);
    setActions(temp);
    debounceNotifyChanges();
  };

  return (
    <div className="aa-adaptivity-editor">
      {/* No Conditions */}
      {currentRule === undefined && (
        <div className="text-center border rounded">
          <div className="card-body">Please select a sequence item</div>
        </div>
      )}

      {currentRule && (isLayer || isBank) && (
        <div className="text-center border rounded">
          <div className="card-body">
            {`This sequence item is a ${sequenceTypeLabel} and does not support adaptivity`}
          </div>
        </div>
      )}

      {/* Has Conditions */}
      {currentRule && !isLayer && !isBank && (
        <>
          {!(currentRule.default && !currentRule.correct) && (
            <ConditionsBlockEditor
              id="root"
              type={rootConditionIsAll ? 'all' : 'any'}
              rootConditions={conditions}
              onChange={handleConditionsEditorChange}
              index={-1}
            />
          )}
          <p className={`${currentRule.default && !currentRule.correct ? '' : 'mt-3'} mb-0`}>
            Perform the following actions:
          </p>
          <div className="aa-actions pt-3 mt-2 d-flex w-100">
            <Dropdown>
              <OverlayTrigger
                placement="top"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="tooltip-top button-tooltip" style={{ fontSize: '12px' }}>
                    New Action
                  </Tooltip>
                }
              >
                <Dropdown.Toggle variant="link" id="adaptive-editor-add-context-trigger">
                  <i className="fa fa-plus" />
                </Dropdown.Toggle>
              </OverlayTrigger>

              <Dropdown.Menu>
                {!hasFeedback && (
                  <Dropdown.Item onClick={() => handleAddAction('feedback')}>
                    <i className="fa fa-comment mr-2" /> Show Feedback
                  </Dropdown.Item>
                )}
                {!hasNavigation && (
                  <Dropdown.Item onClick={() => handleAddAction('navigation')}>
                    <i className="fa fa-compass mr-2" /> Navigate To
                  </Dropdown.Item>
                )}
                <Dropdown.Item onClick={() => handleAddAction('mutateState')}>
                  <i className="fa fa-crosshairs mr-2" /> Mutate State
                </Dropdown.Item>
              </Dropdown.Menu>
            </Dropdown>
            <div className="d-flex flex-column w-100">
              {actions.length === 0 && (
                <div className="text-danger">No actions. This rule will not do anything.</div>
              )}
              {actions.length > 0 &&
                actions.map((action: any, index: number) => getActionEditor(action, index))}
            </div>
          </div>
        </>
      )}
    </div>
  );
};
