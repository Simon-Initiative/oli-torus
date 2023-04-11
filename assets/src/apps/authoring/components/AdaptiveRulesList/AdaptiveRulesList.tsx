import {
  copyItem,
  pasteItem,
  selectCopiedItem,
  selectCopiedType,
  CopyableItemTypes,
} from 'apps/authoring/store/clipboard/slice';
import { usePrevious } from 'components/hooks/usePrevious';
import { debounce } from 'lodash';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip, Dropdown } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import guid from 'utils/guid';
import { clone } from '../../../../utils/common';
import {
  IActivity,
  InitState,
  IAdaptiveRule,
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
import { useToggle } from '../../../../components/hooks/useToggle';

const IRulesList: React.FC = () => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const [open, toggleOpen] = useToggle(true);
  const rules = currentActivity?.authoring?.rules || [];
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

  const handleSelectRule = (rule?: IAdaptiveRule | InitState, isInitState?: boolean) => {
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
        // TODO - we could probably refactor this component to debounce inside saveActivity instead of here.
        dispatch(saveActivity({ activity, undoable: true, immediate: true }));
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
    if (!activityClone.authoring?.rules) return;
    const currentRuleIndex = activityClone.authoring.rules.findIndex(
      (rule: IAdaptiveRule) => rule.id === currentRule.id,
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
    if (!activityClone.authoring?.rules) return;
    const currentRuleIndex = activityClone.authoring.rules.findIndex(
      (rule: IAdaptiveRule) => rule.id === currentRule.id,
    );
    activityClone.authoring.rules.splice(currentRuleIndex + 1, 0, newIncorrectRule);
    activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    debounceSaveChanges(activityClone);
    handleSelectRule(newIncorrectRule);
  };

  const handleDuplicateRule = async (rule: IAdaptiveRule, index: number) => {
    const { payload: newRule } = await dispatch<any>(duplicateRule(rule));

    const activityClone: IActivity = clone(currentActivity);
    if (!activityClone.authoring?.rules) return;
    activityClone.authoring.rules.splice(index + 1, 0, newRule);
    activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    debounceSaveChanges(activityClone);
    handleSelectRule(newRule);
  };

  const handleCopyRule = async (rule: IAdaptiveRule | 'initState') => {
    const copyRule =
      rule === 'initState' ? { facts: currentActivity?.content?.custom?.facts } : rule;

    const { payload: newRule } = await dispatch<any>(duplicateRule(copyRule));

    await dispatch<any>(
      copyItem({ type: rule === 'initState' ? 'initState' : 'rule', item: newRule }),
    );
  };

  const handlePasteRule = async (
    item: IAdaptiveRule | InitState,
    type: CopyableItemTypes | null,
    index: number | 'initState',
  ) => {
    const copyRule = copied;
    let activityClone: IActivity = clone(currentActivity);
    if (!activityClone.authoring?.rules) return;
    const { payload: copy } = await dispatch<any>(copyItem({ type: 'initState', item: copyRule }));
    if (type === 'initState') {
      activityClone = set(activityClone, 'content.custom.facts', copied.facts);
    } else if (typeof index === 'number') {
      activityClone.authoring.rules.splice(index + 1, 0, item as IAdaptiveRule);
      activityClone.authoring.rules = reorderDefaultRules(activityClone.authoring.rules);
    }

    await dispatch<any>(pasteItem({}));

    debounceSaveChanges(activityClone);
    handleSelectRule(item, type === 'initState');
  };

  const handleDeleteRule = (rule: IAdaptiveRule) => {
    const activityClone: IActivity = clone(currentActivity);
    if (!activityClone.authoring?.rules) return;
    const indexToDelete = activityClone.authoring.rules.findIndex(
      (r: IAdaptiveRule) => r.id === rule.id,
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
    if (!activityClone.authoring?.rules) return;
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

  const handleRenameRule = (rule: IAdaptiveRule) => {
    if (ruleToEdit.name.trim() === '') {
      setRuleToEdit(undefined);
      return;
    }
    if (rule.name === ruleToEdit.name) {
      setRuleToEdit(undefined);
      return;
    }
    const activityClone: IActivity = clone(currentActivity);
    if (!activityClone.authoring?.rules) return;
    const indexToRename = activityClone.authoring.rules.findIndex(
      (r: IAdaptiveRule) => r.id === rule.id,
    );

    activityClone.authoring.rules[indexToRename].name = ruleToEdit.name;
    debounceSaveChanges(activityClone);
    setRuleToEdit(undefined);
    handleSelectRule(
      currentRule.id === rule.id ? activityClone.authoring.rules[indexToRename] : currentRule,
    );
  };

  const reorderDefaultRules = (rules: (IAdaptiveRule | InitState)[], saveChanges?: boolean) => {
    // process the rules to make a defaultRule sandwich before displaying them
    const defaultCorrectIndex = rules.findIndex(
      (rule: IAdaptiveRule) => rule.default && rule.correct,
    );
    const defaultWrongIndex = rules.findIndex(
      (rule: IAdaptiveRule) => rule.default && !rule.correct,
    );

    if (defaultCorrectIndex === 0 && defaultWrongIndex === rules.length - 1) return rules;
    const rulesClone = clone(rules);

    // set the defaultCorrect to the first position
    rulesClone.unshift(rulesClone.splice(defaultCorrectIndex, 1)[0]);

    // set the defaultWrong rule to the last position
    rulesClone.push(rulesClone.splice(defaultWrongIndex, 1)[0]);

    if (saveChanges) {
      const activityClone: IActivity = clone(currentActivity);
      if (activityClone.authoring?.rules) {
        activityClone.authoring.rules = rulesClone;
        debounceSaveChanges(activityClone);
      }
    } else return rulesClone;
  };

  const previousActivity = usePrevious(currentActivity);
  useEffect(() => {
    if (currentActivity === undefined) return;
    if (previousActivity?.id !== currentActivity.id && currentActivity.authoring?.rules) {
      reorderDefaultRules(currentActivity.authoring.rules, true);
      handleSelectRule(undefined, true);
    }
  }, [currentActivity]);

  const inputToFocus = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!ruleToEdit) return;
    inputToFocus.current?.focus();
  }, [ruleToEdit]);

  const RuleItemContextMenu = (props: {
    id: string;
    item: IAdaptiveRule | 'initState';
    index: number | 'initState';
    arr?: IAdaptiveRule[];
  }) => {
    const { id, item, index, arr } = props;

    return (
      <Dropdown
        onClick={(e: React.MouseEvent) => {
          (e as any).isContextButtonClick = true;
        }}
      >
        <Dropdown.Toggle
          variant="link"
          id={`rule-list-item-${id}-context-trigger`}
          className="dropdown-toggle aa-context-menu-trigger btn btn-link p-0 px-1"
        >
          <i className="fas fa-ellipsis-v" />
        </Dropdown.Toggle>

        <Dropdown.Menu>
          {item !== 'initState' && (
            <Dropdown.Item onClick={(e) => setRuleToEdit(item)}>
              <i className="fas fa-i-cursor align-text-top mr-2" /> Rename
            </Dropdown.Item>
          )}

          {(item === 'initState' || !item.default || (item.default && item.correct)) && (
            <>
              <Dropdown.Item onClick={(e) => handleCopyRule(item)}>
                <i className="fas fa-copy mr-2" /> Copy
              </Dropdown.Item>
              <Dropdown.Item onClick={(e) => handlePasteRule(copied, copiedType, index)}>
                <i className="fas fa-clipboard mr-2" /> Insert copied rule
              </Dropdown.Item>
            </>
          )}

          {item !== 'initState' && index !== 'initState' && (
            <>
              {!item.default && (
                <>
                  <Dropdown.Item onClick={(e) => handleMoveRule(index, 'down')}>
                    <i className="fas fa-arrow-down mr-2" /> Move Down
                  </Dropdown.Item>
                  <div className="dropdown-divider"></div>
                  <Dropdown.Item onClick={(e) => handleDuplicateRule(item, index)}>
                    <i className="fas fa-copy mr-2" /> Duplicate
                  </Dropdown.Item>
                  <Dropdown.Item
                    onClick={(e) => {
                      setItemToDelete(item);
                      setShowConfirmDelete(true);
                    }}
                  >
                    <i className="fas fa-trash mr-2" /> Delete
                  </Dropdown.Item>
                  <div className="dropdown-divider"></div>
                </>
              )}
              {index > 1 && !item.default && (
                <Dropdown.Item onClick={(e) => handleMoveRule(index, 'up')}>
                  <i className="fas fa-arrow-up mr-2" /> Move Up
                </Dropdown.Item>
              )}
              {arr && index < arr.length - 2 && !item.default && (
                <Dropdown.Item onClick={(e) => handleMoveRule(index, 'down')}>
                  <i className="fas fa-arrow-down mr-2" /> Move Down
                </Dropdown.Item>
              )}
            </>
          )}
        </Dropdown.Menu>
      </Dropdown>
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
    <Accordion className="aa-adaptivity-rules" defaultActiveKey="0" activeKey={open ? '0' : '-1'}>
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <button className="btn btn-link p-0 ml-1" onClick={toggleOpen}>
            {open && (
              <span>
                <i className="fa fa-angle-down" />
              </span>
            )}
            {!open && (
              <span>
                <i className="fa fa-angle-up" />
              </span>
            )}
          </button>
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
            <Dropdown>
              <Dropdown.Toggle variant="link" id="rules-list-add-context-trigger">
                <i className="fa fa-plus" />
              </Dropdown.Toggle>

              <Dropdown.Menu>
                <Dropdown.Item
                  onClick={() => {
                    handleAddCorrectRule();
                  }}
                >
                  <i className="fa fa-check mr-2" /> New Correct Rule
                </Dropdown.Item>
                <Dropdown.Item
                  onClick={() => {
                    handleAddIncorrectRule();
                  }}
                >
                  <i className="fa fa-times mr-2" /> New Incorrect Rule
                </Dropdown.Item>
                <Dropdown.Item
                  onClick={() => {
                    handlePasteRule(copied, copiedType, 0);
                  }}
                >
                  <i className="fas fa-clipboard mr-2" /> Insert copied rule
                </Dropdown.Item>
              </Dropdown.Menu>
            </Dropdown>
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
              onClick={(e) => !(e as any).isContextButtonClick && handleSelectRule(undefined, true)}
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
            rules.map((rule: IAdaptiveRule, index: number, arr: IAdaptiveRule[]) => (
              <ListGroup.Item
                className="aa-rules-list-item"
                as="li"
                key={rule.id}
                active={rule.id === currentRule?.id}
                onClick={(e) => !(e as any).isContextButtonClick && handleSelectRule(rule)}
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
                        ref={inputToFocus}
                        className="form-control form-control-sm text-black"
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

export default IRulesList;
