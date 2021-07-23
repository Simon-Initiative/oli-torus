import React, { useCallback, useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import debounce from 'lodash/debounce';
import { selectCurrentRule } from '../../../authoring/store/app/slice';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import ConditionsBlockEditor from './ConditionsBlockEditor';
import {
  findInSequence,
  getIsLayer,
} from '../../../delivery/store/features/groups/actions/sequence';
import {
  selectCurrentSequenceId,
  selectSequence,
} from '../../../delivery/store/features/groups/selectors/deck';
import ActionFeedbackEditor from './ActionFeedbackEditor';
import ActionMutateEditor from './ActionMutateEditor';
import ActionNavigationEditor from './ActionNavigationEditor';

export interface AdaptivityEditorProps {
  content?: any;
}

export const AdaptivityEditor: React.FC<AdaptivityEditorProps> = (props: AdaptivityEditorProps) => {
  const dispatch = useDispatch();
  const currentRule = useSelector(selectCurrentRule);
  // const currentActivity = useSelector(selectCurrentActivity);
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

  useEffect(() => {
    if (!currentRule) return;
    setIsDisabled(currentRule.disabled);
    setActions(currentRule.event?.params?.actions || []);
    setConditions(currentRule.conditions?.all || currentRule.conditions?.any || []);
    setRootConditionIsAll(!!currentRule.conditions?.all);
  }, [currentRule]);

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
    const conds = updatedConditionsBlock.all || updatedConditionsBlock.any || [];
    if (JSON.stringify(conditions) === JSON.stringify(conds)) {
      return;
    }
    console.log('CONDITION ED: ', updatedConditionsBlock);
    setRootConditionIsAll(!!updatedConditionsBlock.all);
    setConditions(conds);
    debounceNotifyChanges();
  };

  const getActionEditor = (action: any) => {
    switch (action.type) {
      case 'feedback':
        return (
          <ActionFeedbackEditor
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
          />
        );
      case 'navigation':
        return (
          <ActionNavigationEditor
            action={action}
            onChange={(changes: any) => {
              handleActionChange(action, changes);
            }}
          />
        );
      case 'mutateState':
        return (
          <ActionMutateEditor
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
            type={rootConditionIsAll ? 'all' : 'any'}
            defaultConditions={conditions}
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
              <button className="aa-add-button btn btn-primary btn-sm mr-3">
                <i className="fa fa-plus" />
              </button>
            </OverlayTrigger>
            <div className="d-flex flex-column w-100">
              {actions.length === 0 && <div>No actions. This rule will not do anything.</div>}
              {actions.length > 0 &&
                actions.map(
                  (action: any, index: number) => getActionEditor(action),
                  // <div key={index} className="aa-action d-flex mb-2">
                  //   <label className="sr-only" htmlFor="operator">
                  //     operator
                  //   </label>
                  //   <select
                  //     className="custom-select mr-2 form-control form-control-sm w-25"
                  //     id="operator"
                  //     defaultValue="0"
                  //   >
                  //     <option value="0">Choose...</option>
                  //     <option value="1">One</option>
                  //     <option value="2">Two</option>
                  //     <option value="3">Three</option>
                  //   </select>
                  //   <label className="sr-only">value</label>
                  //   <input type="email" className="form-control form-control-sm w-75" id="value" />
                  //   <OverlayTrigger
                  //     placement="top"
                  //     delay={{ show: 150, hide: 150 }}
                  //     overlay={
                  //       <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                  //         Delete Action
                  //       </Tooltip>
                  //     }
                  //   >
                  //     <span>
                  //       <button className="btn btn-link p-0 ml-1">
                  //         <i className="fa fa-trash-alt" />
                  //       </button>
                  //     </span>
                  //   </OverlayTrigger>
                  // </div>
                )}
            </div>
          </div>
        </>
      )}
    </div>
  );
};
