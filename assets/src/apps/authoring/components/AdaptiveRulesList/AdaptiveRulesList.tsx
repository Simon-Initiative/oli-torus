import React, { useEffect, useCallback, useState } from 'react';
import { debounce } from 'lodash';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { createCorrectRule, createIncorrectRule } from '../../store/activities/actions/rules';
import {
  IActivity,
  selectCurrentActivity,
  upsertActivity,
} from '../../../delivery/store/features/activities/slice';
import { selectCurrentRule, setCurrentRule } from '../../store/app/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { clone } from '../../../../utils/common';
import guid from 'utils/guid';

const AdaptiveRulesList: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const rules = currentActivity?.authoring.rules || [];
  const [ruleToEdit, setRuleToEdit] = useState<any>(undefined);

  const handleSelectRule = (rule: any) => dispatch(setCurrentRule({ currentRule: rule }));

  const debounceSaveChanges = useCallback(
    debounce(
      (activity) => {
        dispatch(saveActivity({ activity }));
        dispatch(upsertActivity({ activity }));
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
    activityClone.authoring.rules.push(newCorrectRule);
    handleSelectRule(newCorrectRule);
    debounceSaveChanges(activityClone);
  };

  const handleAddIncorrectRule = async () => {
    const { payload: newIncorrectRule } = await dispatch<any>(
      createIncorrectRule({ isDefault: false }),
    );
    const activityClone: IActivity = clone(currentActivity);
    activityClone.authoring.rules.push(newIncorrectRule);
    handleSelectRule(newIncorrectRule);
    debounceSaveChanges(activityClone);
  };

  const handleDeleteRule = (rule: any) => {
    const activityClone: IActivity = clone(currentActivity);
    const indexToDelete = activityClone.authoring.rules.findIndex((r: any) => r.id === rule.id);
    const isActiveRule: boolean = rule.id === currentRule.id;

    if (indexToDelete !== -1) {
      activityClone.authoring.rules.splice(indexToDelete, 1);
      const prevRule = activityClone.authoring.rules[indexToDelete - 1];
      const nextRule = activityClone.authoring.rules[indexToDelete + 1];
      handleSelectRule(isActiveRule ? (prevRule !== undefined ? prevRule : nextRule) : currentRule);
      debounceSaveChanges(activityClone);
    }
  };

  const handleRenameRule = (rule: any) => {
    if (ruleToEdit.name.trim() === '') return;
    if (rule.name === ruleToEdit.name) {
      setRuleToEdit(undefined);
      return;
    }
    const activityClone: IActivity = clone(currentActivity);
    const indexToRename = activityClone.authoring.rules.findIndex((r: any) => r.id === rule.id);
    activityClone.authoring.rules[indexToRename].name = ruleToEdit.name;
    debounceSaveChanges(activityClone);
    setRuleToEdit(undefined);
    handleSelectRule(
      currentRule.id === rule.id ? activityClone.authoring.rules[indexToRename] : currentRule,
    );
  };

  useEffect(() => {
    if (currentRule !== undefined) return;
    rules.length > 0 ? handleSelectRule(rules[0]) : handleSelectRule(undefined);
  }, [currentActivity]);

  useEffect(() => {
    if (!ruleToEdit) return;
    const inputToFocus = document.getElementById('input-rule-name');
    if (inputToFocus) inputToFocus.focus();
  }, [ruleToEdit]);

  const RuleItemContextMenu = (props: any) => {
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
            </>
          )}
        </div>
      </div>
    );
  };

  const RuleName = ({ rule }: any) => {
    return (
      <span>
        {rule.default && rule.correct && (
          <i className="fa fa-check-circle mr-1 text-muted align-middle" />
        )}
        {rule.default && !rule.correct && (
          <i className="fa fa-times-circle mr-1 text-muted align-middle" />
        )}
        <span className="title">{rule.name}</span>
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
        {currentRule && (
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
            rules.map((rule: any, index: any, arr: any) => (
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
          {!currentRule && <span>No screen selected</span>}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AdaptiveRulesList;
