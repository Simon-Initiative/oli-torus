import { usePrevious } from 'components/hooks/usePrevious';
import { debounce } from 'lodash';
import React, { useCallback, useEffect, useState } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import guid from 'utils/guid';
import { clone } from '../../../../utils/common';
import {
  IActivity,
  selectCurrentActivity,
} from '../../../delivery/store/features/activities/slice';
import { getIsLayer } from '../../../delivery/store/features/groups/actions/sequence';
import { createCorrectRule, createIncorrectRule } from '../../store/activities/actions/rules';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { selectCurrentRule, setCurrentRule } from '../../store/app/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

export interface AdaptiveRule {
  id?: string;
  name: string;
  disabled: boolean;
  additionalScore?: number;
  forceProgress?: boolean;
  default: boolean;
  correct: boolean;
  conditions: {};
  event: {};
}

const AdaptiveRulesList: React.FC = () => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const isLayer = getIsLayer();
  const rules = currentActivity?.authoring.rules || [];
  const [ruleToEdit, setRuleToEdit] = useState<any>(undefined);

  const handleSelectRule = (rule: AdaptiveRule) => dispatch(setCurrentRule({ currentRule: rule }));

  const debounceSaveChanges = useCallback(
    debounce(
      (activity) => {
        dispatch(saveActivity({ activity }));
      },
      500,
      { maxWait: 10000, leading: false },
    ),
    [],
  );

  const handleAddCorrectRule = async () => {
    const { payload: newCorrectRule } = await dispatch<any>(
      createCorrectRule({ isDefault: false }),
    );
    const activityClone: IActivity = clone(currentActivity);
    const currentRuleIndex = activityClone.authoring.rules.findIndex(
      (rule: AdaptiveRule) => rule.id === currentRule.id,
    );
    activityClone.authoring.rules.splice(currentRuleIndex + 1, 0, newCorrectRule);
    activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    debounceSaveChanges(activityClone);
    handleSelectRule(newCorrectRule);
  };

  const handleAddIncorrectRule = async () => {
    const { payload: newIncorrectRule } = await dispatch<any>(
      createIncorrectRule({ isDefault: false }),
    );
    const activityClone: IActivity = clone(currentActivity);
    const currentRuleIndex = activityClone.authoring.rules.findIndex(
      (rule: AdaptiveRule) => rule.id === currentRule.id,
    );
    activityClone.authoring.rules.splice(currentRuleIndex + 1, 0, newIncorrectRule);
    activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    debounceSaveChanges(activityClone);
    handleSelectRule(newIncorrectRule);
  };

  const handleDeleteRule = (rule: AdaptiveRule) => {
    const activityClone: IActivity = clone(currentActivity);
    const indexToDelete = activityClone.authoring.rules.findIndex(
      (r: AdaptiveRule) => r.id === rule.id,
    );
    const isActiveRule: boolean = rule.id === currentRule.id;

    if (indexToDelete !== -1) {
      activityClone.authoring.rules.splice(indexToDelete, 1);
      const prevRule = activityClone.authoring.rules[indexToDelete - 1];
      const nextRule = activityClone.authoring.rules[indexToDelete + 1];
      debounceSaveChanges(activityClone);
      handleSelectRule(isActiveRule ? (prevRule !== undefined ? prevRule : nextRule) : currentRule);
    }
  };

  const handleMoveRule = (ruleIndex: number, direction: string) => {
    const activityClone: IActivity = clone(currentActivity);
    const ruleToMove = activityClone.authoring.rules.splice(ruleIndex, 1)[0];
    switch (direction) {
      case 'down':
        activityClone.authoring.rules.splice(ruleIndex + 1, 0, ruleToMove);
        break;
      case 'up':
        activityClone.authoring.rules.splice(ruleIndex - 1, 0, ruleToMove);
        break;
      default:
        break;
    }
    debounceSaveChanges(activityClone);
  };

  const handleRenameRule = (rule: AdaptiveRule) => {
    if (ruleToEdit.name.trim() === '') {
      setRuleToEdit(undefined);
      return;
    }
    if (rule.name === ruleToEdit.name) {
      setRuleToEdit(undefined);
      return;
    }
    const activityClone: IActivity = clone(currentActivity);
    const indexToRename = activityClone.authoring.rules.findIndex(
      (r: AdaptiveRule) => r.id === rule.id,
    );
    activityClone.authoring.rules[indexToRename].name = ruleToEdit.name;
    debounceSaveChanges(activityClone);
    setRuleToEdit(undefined);
    handleSelectRule(
      currentRule.id === rule.id ? activityClone.authoring.rules[indexToRename] : currentRule,
    );
  };

  const reorderDefaultRules = (rules: AdaptiveRule[], saveChanges?: boolean) => {
    // process the rules to make a defaultRule sandwich before displaying them
    const defaultCorrectIndex = rules.findIndex(
      (rule: AdaptiveRule) => rule.default && rule.correct,
    );
    const defaultWrongIndex = rules.findIndex(
      (rule: AdaptiveRule) => rule.default && !rule.correct,
    );

    if (defaultCorrectIndex === 0 && defaultWrongIndex === rules.length - 1) return rules;
    const rulesClone = clone(rules);

    // set the defaultCorrect to the first position
    rulesClone.unshift(rulesClone.splice(defaultCorrectIndex, 1)[0]);

    // set the defaultWrong rule to the last position
    rulesClone.push(rulesClone.splice(defaultWrongIndex, 1)[0]);

    if (saveChanges) {
      const activityClone: IActivity = clone(currentActivity);
      activityClone.authoring.rules = rulesClone;
      debounceSaveChanges(activityClone);
    } else return rulesClone;
  };

  const previousActivity = usePrevious(currentActivity);
  useEffect(() => {
    if (currentActivity === undefined) return;
    if (previousActivity?.id !== currentActivity.id) {
      reorderDefaultRules(currentActivity.authoring.rules, true);
      handleSelectRule(currentActivity.authoring.rules[0]);
    }
  }, [currentActivity]);

  useEffect(() => {
    if (!ruleToEdit) return;
    const inputToFocus = document.getElementById('input-rule-name');
    if (inputToFocus) inputToFocus.focus();
  }, [ruleToEdit]);

  const RuleItemContextMenu = (props: {
    id: string;
    item: AdaptiveRule;
    index: number;
    arr: AdaptiveRule[];
  }) => {
    const { id, item, index, arr } = props;

    return (
      <div key={id} className="dropdown aa-sequence-item-context-menu">
        <button
          className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1"
          type="button"
          id={`rule-list-item-${id}-context-trigger`}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
          onClick={(e) => {
            e.stopPropagation();
            ($(`#rule-list-item-${id}-context-trigger`) as any).dropdown('toggle');
          }}
        >
          <i className="fas fa-ellipsis-v" />
        </button>
        <div
          id={`rule-list-item-${id}-context-menu`}
          className="dropdown-menu"
          aria-labelledby={`rule-list-item-${id}-context-trigger`}
        >
          <button
            className="dropdown-item"
            onClick={(e) => {
              e.stopPropagation();
              ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
              setRuleToEdit(item);
            }}
          >
            <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
          </button>
          {!item.default && (
            <>
              <div className="dropdown-divider"></div>
              <button
                className="dropdown-item text-danger"
                onClick={(e) => {
                  e.stopPropagation();
                  ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
                  handleDeleteRule(item);
                }}
              >
                <i className="fas fa-trash mr-2" /> Delete
              </button>
              <div className="dropdown-divider"></div>
            </>
          )}
          {index > 1 && !item.default && (
            <button
              className="dropdown-item"
              onClick={(e) => {
                e.stopPropagation();
                handleMoveRule(index, 'up');
                ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
              }}
            >
              <i className="fas fa-arrow-up mr-2" /> Move Up
            </button>
          )}
          {index < arr.length - 2 && !item.default && (
            <button
              className="dropdown-item"
              onClick={(e) => {
                e.stopPropagation();
                handleMoveRule(index, 'down');
                ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
              }}
            >
              <i className="fas fa-arrow-down mr-2" /> Move Down
            </button>
          )}
        </div>
      </div>
    );
  };

  const RuleName = ({ rule }: any) => {
    return (
      <span>
        {rule.correct && <i className="fa fa-check-circle mr-1 text-muted align-middle" />}
        {!rule.correct && <i className="fa fa-times-circle mr-1 text-muted align-middle" />}
        <span
          className={`title${rule.default ? ' font-italic' : ''}${
            rule.disabled ? ' strikethru' : ''
          }`}
        >
          {rule.name}
        </span>
      </span>
    );
  };

  return (
    <Accordion className="aa-adaptivity-rules" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Adaptivity</span>
        </div>
        {currentRule && !isLayer && (
          <OverlayTrigger
            placement="right"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                New Rule
              </Tooltip>
            }
          >
            <div className="dropdown">
              <button
                className="dropdown-toggle btn btn-link p-0 ml-1"
                type="button"
                id={`rules-list-add-context-trigger`}
                data-toggle="dropdown"
                aria-haspopup="true"
                aria-expanded="false"
                onClick={(e) => {
                  ($(`#rules-list-add-context-trigger`) as any).dropdown('toggle');
                }}
              >
                <i className="fa fa-plus" />
              </button>
              <div
                id={`rules-list-add-context-menu`}
                className="dropdown-menu"
                aria-labelledby={`rules-list-add-context-trigger`}
              >
                <button
                  className="dropdown-item"
                  onClick={() => {
                    handleAddCorrectRule();
                  }}
                >
                  <i className="fa fa-check mr-2" /> New Correct Rule
                </button>
                <button
                  className="dropdown-item"
                  onClick={() => {
                    handleAddIncorrectRule();
                  }}
                >
                  <i className="fa fa-times mr-2" /> New Incorrect Rule
                </button>
              </div>
            </div>
          </OverlayTrigger>
        )}
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup className="aa-rules-list" as="ol">
          {currentRule &&
            !isLayer &&
            rules.map((rule: AdaptiveRule, index: number, arr: AdaptiveRule[]) => (
              <ListGroup.Item
                className="aa-rules-list-item"
                as="li"
                key={rule.id}
                active={rule.id === currentRule?.id}
                onClick={() => handleSelectRule(rule)}
              >
                <div className="aa-rules-list-details-wrapper">
                  <div className="details">
                    {!ruleToEdit ? (
                      <RuleName rule={rule} />
                    ) : ruleToEdit?.id !== rule.id ? (
                      <RuleName rule={rule} />
                    ) : null}
                    {ruleToEdit && ruleToEdit?.id === rule.id && (
                      <input
                        id="input-rule-name"
                        className="form-control form-control-sm"
                        type="text"
                        placeholder="Rule name"
                        value={ruleToEdit.name}
                        onClick={(e) => e.preventDefault()}
                        onChange={(e) => setRuleToEdit({ ...rule, name: e.target.value })}
                        onFocus={(e) => e.target.select()}
                        onBlur={() => handleRenameRule(rule)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter') handleRenameRule(rule);
                          if (e.key === 'Escape') setRuleToEdit(undefined);
                        }}
                      />
                    )}
                  </div>
                  <RuleItemContextMenu id={guid()} item={rule} index={index} arr={arr} />
                </div>
              </ListGroup.Item>
            ))}
          {!currentRule && (
            <div className="text-center border rounded m-3">
              <div className="card-body">
                <p>
                  <small>Please select a sequence item</small>
                </p>
              </div>
            </div>
          )}
          {currentRule && isLayer && (
            <div className="text-center border rounded m-3">
              <div className="card-body">
                <p>
                  <small>This sequence item is a layer and does not support adaptivity</small>
                </p>
              </div>
            </div>
          )}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AdaptiveRulesList;
