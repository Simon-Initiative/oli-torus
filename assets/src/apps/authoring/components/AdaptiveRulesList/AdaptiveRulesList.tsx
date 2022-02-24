import {
  copyItem,
  pasteItem,
  selectCopiedItem,
  selectCopiedType,
  CopyableItemTypes,
} from 'apps/authoring/store/clipboard/slice';
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
import { getIsLayer, getIsBank } from '../../../delivery/store/features/groups/actions/sequence';
import {
  createCorrectRule,
  createIncorrectRule,
  duplicateRule,
} from '../../store/activities/actions/rules';
import { saveActivity } from '../../store/activities/actions/saveActivity';
import { selectCurrentRule, setCurrentRule } from '../../store/app/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import set from 'lodash/set';

export interface AdaptiveRule {
  id?: string;
  name: string;
  disabled: boolean;
  additionalScore?: number;
  forceProgress?: boolean;
  default: boolean;
  correct: boolean;
  conditions: Record<string, unknown>;
  event: Record<string, unknown>;
}

export interface InitState {
  facts: any[];
}

const AdaptiveRulesList: React.FC = () => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const rules = currentActivity?.authoring.rules || [];
  const [ruleToEdit, setRuleToEdit] = useState<any>(undefined);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const [itemToDelete, setItemToDelete] = useState<any>(undefined);
  const isLayer = getIsLayer();
  const isBank = getIsBank();
  let sequenceTypeLabel = '';
  if (isLayer) {
    sequenceTypeLabel = 'layer';
  } else if (isBank) {
    sequenceTypeLabel = 'question bank';
  } else {
    sequenceTypeLabel = 'screen';
  }

  const copied = useSelector(selectCopiedItem);
  const copiedType = useSelector(selectCopiedType);

  useEffect(() => console.log(copied), [copied]);

  const handleSelectRule = (rule?: AdaptiveRule | InitState, isInitState?: boolean) => {
    if (isInitState) {
      // TODO: refactor initState string to enum
      dispatch(setCurrentRule({ currentRule: 'initState' }));
    } else {
      dispatch(setCurrentRule({ currentRule: rule }));
    }
  };

  const debounceSaveChanges = useCallback(
    debounce(
      (activity) => {
        dispatch(saveActivity({ activity, undoable: true }));
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

  const handleDuplicateRule = async (rule: AdaptiveRule, index: number) => {
    const { payload: newRule } = await dispatch<any>(duplicateRule(rule));

    const activityClone: IActivity = clone(currentActivity);
    activityClone.authoring.rules.splice(index + 1, 0, newRule);
    activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    debounceSaveChanges(activityClone);
    handleSelectRule(newRule);
  };

  const handleCopyRule = async (rule: AdaptiveRule | 'initState') => {
    const copyRule =
      rule === 'initState' ? { facts: currentActivity?.content?.custom?.facts } : rule;

    const { payload: newRule } = await dispatch<any>(duplicateRule(copyRule));

    await dispatch<any>(
      copyItem({ type: rule === 'initState' ? 'initState' : 'rule', item: newRule }),
    );
  };

  const handlePasteRule = async (
    item: AdaptiveRule | InitState,
    type: CopyableItemTypes | null,
    index: number | 'initState',
  ) => {
    const copyRule = copied;
    let activityClone: IActivity = clone(currentActivity);
    const { payload: copy } = await dispatch<any>(copyItem({ type: 'initState', item: copyRule }));
    if (type === 'initState') {
      activityClone = set(activityClone, 'content.custom.facts', copied.facts);
    } else if (typeof index === 'number') {
      activityClone.authoring.rules.splice(index + 1, 0, item);
      activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    }

    await dispatch<any>(pasteItem({}));

    debounceSaveChanges(activityClone);
    handleSelectRule(item, type === 'initState');
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
    setItemToDelete(undefined);
    setShowConfirmDelete(false);
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
      handleSelectRule(undefined, true);
    }
  }, [currentActivity]);

  useEffect(() => {
    if (!ruleToEdit) return;
    const inputToFocus = document.getElementById('input-rule-name');
    if (inputToFocus) inputToFocus.focus();
  }, [ruleToEdit]);

  const RuleItemContextMenu = (props: {
    id: string;
    item: AdaptiveRule | 'initState';
    index: number | 'initState';
    arr?: AdaptiveRule[];
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
          <>
            {item !== 'initState' && (
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
            )}
          </>
          {(item === 'initState' || !item.default || (item.default && item.correct)) && (
            <>
              <button
                className="dropdown-item"
                onClick={(e) => {
                  e.stopPropagation();
                  handleCopyRule(item);
                  ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
                }}
              >
                <i className="fas fa-copy mr-2" /> Copy
              </button>
              <button
                className="dropdown-item"
                disabled={!copied}
                onClick={(e) => {
                  e.stopPropagation();
                  handlePasteRule(copied, copiedType, index);
                  ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
                }}
              >
                <i className="fas fa-clipboard mr-2" /> Insert copied rule
              </button>
            </>
          )}
          {item !== 'initState' && index !== 'initState' && (
            <>
              {!item.default && (
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
              {!item.default && (
                <>
                  <div className="dropdown-divider"></div>
                  <button
                    className="dropdown-item"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDuplicateRule(item, index);
                      ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
                    }}
                  >
                    <i className="fas fa-copy mr-2" /> Duplicate
                  </button>
                  <button
                    className="dropdown-item text-danger"
                    onClick={(e) => {
                      e.stopPropagation();
                      ($(`#rule-list-item-${id}-context-menu`) as any).dropdown('toggle');
                      setItemToDelete(item);
                      setShowConfirmDelete(true);
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
              {arr && index < arr.length - 2 && !item.default && (
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
            </>
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
        {currentRule && !isLayer && !isBank && (
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
                onClick={() => {
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
                <button
                  className="dropdown-item"
                  onClick={() => {
                    handlePasteRule(copied, copiedType, 0);
                  }}
                >
                  <i className="fas fa-clipboard mr-2" /> Insert copied rule
                </button>
              </div>
            </div>
          </OverlayTrigger>
        )}
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup className="aa-rules-list" as="ol">
          {currentRule && !isLayer && !isBank && (
            <ListGroup.Item
              className="aa-rules-list-item"
              as="li"
              active={currentRule === 'initState'}
              onClick={() => handleSelectRule(undefined, true)}
            >
              <div className="aa-rules-list-details-wrapper">
                <div className="details">
                  <span>
                    <i className="fa fa-info-circle mr-1 text-muted align-middle" />
                    <span className="title font-italic">Initial State</span>
                  </span>
                </div>
                <RuleItemContextMenu id={guid()} item={'initState'} index={'initState'} />
              </div>
            </ListGroup.Item>
          )}
          {currentRule &&
            !isLayer &&
            !isBank &&
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
          {currentRule && (isLayer || isBank) && (
            <div className="text-center border rounded m-3">
              <div className="card-body">
                <p>
                  <small>{`This sequence item is a ${sequenceTypeLabel} and does not support adaptivity`}</small>
                </p>
              </div>
            </div>
          )}
        </ListGroup>
      </Accordion.Collapse>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Rule"
          elementName={itemToDelete.name}
          deleteHandler={() => handleDeleteRule(itemToDelete)}
          cancelHandler={() => {
            setShowConfirmDelete(false);
            setItemToDelete(undefined);
          }}
        />
      )}
    </Accordion>
  );
};

export default AdaptiveRulesList;
