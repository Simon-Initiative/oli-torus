import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { selectCurrentRule } from '../../../authoring/store/app/slice';
import {
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import { getIsLayer } from '../../../delivery/store/features/groups/actions/sequence';
import ActionFeedbackEditor from './ActionFeedbackEditor';
import ActionMutateEditor from './ActionMutateEditor';
import ActionNavigationEditor from './ActionNavigationEditor';
import ConditionsBlockEditor from './ConditionsBlockEditor';
import isEqual from 'lodash/isEqual';

export interface AdaptivityEditorProps {
  content?: any;
}

export const AdaptivityEditor: React.FC<AdaptivityEditorProps> = (props: AdaptivityEditorProps) => {
  const dispatch = useDispatch();
  const currentRule = useSelector(selectCurrentRule);
  const currentActivity = useSelector(selectCurrentActivity);
  const isLayer = getIsLayer();

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
    const existing = currentActivity?.authoring.rules.find((r: any) => r.id === rule.id);
    const diff = JSON.stringify(rule) !== JSON.stringify(existing);
    console.log('RULE CHANGE: ', {
      rule,
      existing,
      diff,
    });
    if (!existing) {
      console.warn("rule not found, shouldn't happen!!!");
      return;
    }
    if (diff) {
      const activityClone = clone(currentActivity);
      const rulesClone = [...currentActivity?.authoring.rules];
      rulesClone[currentActivity?.authoring.rules.indexOf(existing)] = rule;
      activityClone.authoring.rules = rulesClone;
      dispatch(saveActivity({ activity: activityClone }));
      dispatch(upsertActivity({ activity: activityClone }));
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
    console.log('CONDITION ED: ', updatedConditionsBlock);
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

  const getActionEditor = (action: any) => {
    switch (action.type) {
      case 'feedback':
        return (
          <ActionFeedbackEditor
            key={guid()}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
          />
        );
      case 'navigation':
        return (
          <ActionNavigationEditor
            key={guid()}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
          />
        );
      case 'mutateState':
        return (
          <ActionMutateEditor
            key={guid()}
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
          />
        );
    }
  };

  const handleActionChange = async (action: any, changes: any) => {
    const updated = { ...action, params: { ...action.params, ...changes } };
    const actionIndex = actions.indexOf(action);
    console.log('action changed', { action, changes, actionIndex });
    if (actionIndex !== -1) {
      const cloneActions = [...actions];
      cloneActions[actionIndex] = updated;
      setActions(cloneActions);
      debounceNotifyChanges();
    }
  };

  return (
    <div className="aa-adaptivity-editor">
      {/* No Conditions */}
      {currentRule === undefined && (
        <div className="text-center border rounded">
          <div className="card-body">Please select a sequence item</div>
        </div>
      )}

      {currentRule && isLayer && (
        <div className="text-center border rounded">
          <div className="card-body">
            This sequence item is a layer and does not support adaptivity
          </div>
        </div>
      )}

      {/* Has Conditions */}
      {currentRule && !isLayer && (
        <>
          <ConditionsBlockEditor
            id="root"
            type={rootConditionIsAll ? 'all' : 'any'}
            rootConditions={conditions}
            onChange={handleConditionsEditorChange}
          />
          <p className="mt-3 mb-0">Perform the following actions:</p>
          <div className="aa-actions pt-3 mt-2 d-flex w-100">
            <OverlayTrigger
              placement="top"
              delay={{ show: 150, hide: 150 }}
              overlay={
                <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  New Action
                </Tooltip>
              }
            >
              <button
                className="dropdown-toggle aa-add-button btn btn-primary btn-sm mr-3"
                type="button"
                id={`adaptive-editor-add-context-trigger`}
                data-toggle="dropdown"
                aria-haspopup="true"
                aria-expanded="false"
                onClick={(e) => {
                  ($(`#adaptive-editor-add-context-trigger`) as any).dropdown('toggle');
                }}
              >
                <i className="fa fa-plus" />
              </button>
            </OverlayTrigger>
            <div
              id={`adaptive-editor-add-context-menu`}
              className="dropdown-menu"
              aria-labelledby={`adaptive-editor-add-context-trigger`}
            >
              {!hasFeedback && (
                <button className="dropdown-item">
                  <i className="fa fa-comment mr-2" /> Show Feedback
                </button>
              )}
              {!hasNavigation && (
                <button className="dropdown-item">
                  <i className="fa fa-compass mr-2" /> Navigate To
                </button>
              )}
              <button className="dropdown-item">
                <i className="fa fa-crosshairs mr-2" /> Mutate State
              </button>
            </div>
            <div className="d-flex flex-column w-100">
              {actions.length === 0 && <div>No actions. This rule will not do anything.</div>}
              {actions.length > 0 && actions.map((action: any) => getActionEditor(action))}
            </div>
          </div>
        </>
      )}
    </div>
  );
};
