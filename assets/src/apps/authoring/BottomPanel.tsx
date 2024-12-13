import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Dropdown, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { debounce } from 'lodash';
import { clone } from '../../utils/common';
import {
  IActivity,
  IAdaptiveRule,
  selectCurrentActivity,
} from '../delivery/store/features/activities/slice';
import { getIsLayer } from '../delivery/store/features/groups/actions/sequence';
import ConfirmDelete from './components/Modal/DeleteConfirmationModal';
import { createCorrectRule, createIncorrectRule } from './store/activities/actions/rules';
import { saveActivity } from './store/activities/actions/saveActivity';
import { selectCurrentRule, setCurrentRule } from './store/app/slice';

export interface BottomPanelProps {
  panelState: any;
  onToggle: any;
  children?: any;
  content?: any;
  sidebarExpanded?: boolean;
}

export const BottomPanel: React.FC<BottomPanelProps> = (props: BottomPanelProps) => {
  const { panelState, onToggle, children, sidebarExpanded } = props;
  const PANEL_SIDE_WIDTH = '270px';
  const dispatch = useDispatch();
  const currentRule = useSelector(selectCurrentRule);
  const currentActivity = useSelector(selectCurrentActivity);
  const [correct, setCorrect] = useState(false);
  const [isDisabled, setIsDisabled] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const isLayer = getIsLayer();

  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    if (currentRule === undefined) return;
    if (currentRule !== 'initState') {
      setCorrect(currentRule.correct);
      setIsDisabled(!!currentRule.disabled);
    }
  }, [currentRule]);

  const handleCorrectChange = () => {
    const activityClone: IActivity = clone(currentActivity);
    const updatedRule = { ...currentRule, correct: !correct };
    const ruleToUpdate = activityClone.authoring?.rules?.find(
      (rule: IAdaptiveRule) => rule.id === updatedRule.id,
    );
    if (!ruleToUpdate) return;
    ruleToUpdate.correct = !correct;
    dispatch(setCurrentRule({ currentRule: updatedRule }));
    setCorrect(!correct);
    debounceSaveChanges(activityClone);
  };

  const handleDisabledChange = () => {
    const activityClone: IActivity = clone(currentActivity);
    const updatedRule = { ...currentRule, disabled: !isDisabled };
    const ruleToUpdate = activityClone.authoring?.rules?.find(
      (rule: IAdaptiveRule) => rule.id === updatedRule.id,
    );
    if (!ruleToUpdate) return;
    ruleToUpdate.disabled = !isDisabled;
    dispatch(setCurrentRule({ currentRule: updatedRule }));
    setIsDisabled(!isDisabled);
    debounceSaveChanges(activityClone);
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

  const reorderDefaultRules = (rules: IAdaptiveRule[], saveChanges?: boolean) => {
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

    if (saveChanges && currentActivity?.authoring) {
      const activityClone: IActivity = clone(currentActivity);
      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      activityClone.authoring!.rules = rulesClone;
      debounceSaveChanges(activityClone);
    } else return rulesClone;
  };

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
    dispatch(setCurrentRule({ currentRule: newCorrectRule }));
    debounceSaveChanges(activityClone);
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
    dispatch(setCurrentRule({ currentRule: newIncorrectRule }));
    debounceSaveChanges(activityClone);
  };

  const handleDeleteRule = () => {
    const activityClone: IActivity = clone(currentActivity);
    if (!activityClone.authoring?.rules) return;
    const indexToDelete = activityClone.authoring.rules.findIndex(
      (rule: IAdaptiveRule) => rule.id === currentRule.id,
    );
    if (indexToDelete !== -1) {
      activityClone.authoring.rules.splice(indexToDelete, 1);
      const prevRule = activityClone.authoring.rules[indexToDelete - 1];
      const nextRule = activityClone.authoring.rules[indexToDelete + 1];
      dispatch(setCurrentRule({ currentRule: prevRule !== undefined ? prevRule : nextRule }));
      debounceSaveChanges(activityClone);
    }
    setShowConfirmDelete(false);
  };

  return (
    <>
      <section
        id="aa-bottom-panel"
        ref={ref}
        className={`aa-panel mt-8 bottom-panel${panelState['bottom'] ? ' open' : ''} ${
          !sidebarExpanded ? '' : 'ml-[135px]'
        }`}
        style={{
          left: panelState['left'] ? '335px' : '65px', // 335 = PANEL_SIDE_WIDTH + 65px (torus sidebar width)
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
          bottom:
            panelState['bottom'] || !ref.current
              ? 0
              : `calc(-${ref.current?.clientHeight}px + 39px)`,
        }}
      >
        <div className="aa-panel-inner">
          <div className="aa-panel-section-title-bar">
            <div className="aa-panel-section-title pl-2">
              <span className="title">rule editor</span>
              {currentRule && !isLayer && (
                <span className="ruleName">
                  {currentRule === 'initState' ? 'Initial State' : currentRule.name}
                </span>
              )}
            </div>
            <div className="aa-panel-section-controls d-flex justify-content-center align-items-center">
              {currentRule &&
                currentRule.default &&
                currentRule.correct &&
                currentRule !== 'initState' && (
                  <div className="disable-state-toggle pr-3 mr-0 d-flex justify-content-center align-items-center form-check form-check-inline">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="disable-state-toggle"
                      checked={isDisabled}
                      onChange={() => handleDisabledChange()}
                    />
                    <label className="form-check-label" htmlFor="disable-state-toggle">
                      Disable State
                    </label>
                  </div>
                )}
              {currentRule && !isLayer && !currentRule.default && currentRule !== 'initState' && (
                <>
                  <div className="correct-toggle pr-3 d-flex justify-content-center align-items-center">
                    <i className="fa fa-times mr-2" />
                    <div className="custom-control custom-switch">
                      <input
                        type="checkbox"
                        className="custom-control-input"
                        id={`correct-toggle`}
                        checked={correct}
                        onChange={() => handleCorrectChange()}
                      />
                      <label className="custom-control-label" htmlFor={`correct-toggle`}></label>
                    </div>
                    <i className="fa fa-check" />
                  </div>
                  <OverlayTrigger
                    placement="top"
                    delay={{ show: 150, hide: 150 }}
                    overlay={
                      <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                        Delete Rule
                      </Tooltip>
                    }
                  >
                    <span>
                      <button
                        className="btn btn-link p-0 ml-3"
                        onClick={() => setShowConfirmDelete(true)}
                      >
                        <i className="fa fa-trash-alt" />
                      </button>
                    </span>
                  </OverlayTrigger>
                </>
              )}
              {currentRule && !isLayer && (
                <OverlayTrigger
                  placement="top"
                  delay={{ show: 150, hide: 150 }}
                  overlay={
                    <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                      New Rule
                    </Tooltip>
                  }
                >
                  <Dropdown>
                    <Dropdown.Toggle
                      id="bottom-panel-add-context-trigger"
                      variant="link"
                      className={`dropdown-toggle btn btn-link p-0 ${
                        currentRule?.default ? 'ml-3' : 'ml-1'
                      }`}
                    >
                      <i className="fa fa-plus" />
                    </Dropdown.Toggle>

                    <Dropdown.Menu>
                      <Dropdown.Item onClick={() => handleAddCorrectRule()}>
                        <i className="fa fa-check mr-2" /> New Correct Rule
                      </Dropdown.Item>
                      <Dropdown.Item onClick={() => handleAddIncorrectRule()}>
                        {' '}
                        <i className="fa fa-times mr-2" /> New Incorrect Rule
                      </Dropdown.Item>
                    </Dropdown.Menu>
                  </Dropdown>
                </OverlayTrigger>
              )}
              <button className="btn btn-link p-0 ml-1" onClick={() => onToggle()}>
                {panelState['bottom'] && (
                  <span>
                    <i className="fa fa-angle-down" />
                  </span>
                )}
                {!panelState['bottom'] && (
                  <span>
                    <i className="fa fa-angle-up" />
                  </span>
                )}
              </button>
            </div>
          </div>
          {children}
        </div>
      </section>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Rule"
          elementName={currentRule.name}
          deleteHandler={() => handleDeleteRule()}
          cancelHandler={() => {
            setShowConfirmDelete(false);
          }}
        />
      )}
    </>
  );
};
