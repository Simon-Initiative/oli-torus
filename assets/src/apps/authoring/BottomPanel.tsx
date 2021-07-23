import React, { useEffect, useState, useCallback } from 'react';
import { debounce } from 'lodash';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  IActivity,
  selectCurrentActivity,
  upsertActivity,
} from '../delivery/store/features/activities/slice';
import { selectCurrentRule, setCurrentRule } from './store/app/slice';
import { clone } from '../../utils/common';
import { saveActivity } from './store/activities/actions/saveActivity';
import { createCorrectRule, createIncorrectRule } from './store/activities/actions/rules';
import { getIsLayer } from '../delivery/store/features/groups/actions/sequence';

export interface BottomPanelProps {
  panelState: any;
  onToggle: any;
  children?: any;
  content?: any;
}

export const BottomPanel: React.FC<BottomPanelProps> = (props: BottomPanelProps) => {
  const { panelState, onToggle, children } = props;
  const PANEL_SIDE_WIDTH = '250px';
  const dispatch = useDispatch();
  const currentRule = useSelector(selectCurrentRule);
  const currentActivity = useSelector(selectCurrentActivity);
  const [correct, setCorrect] = useState(false);
  const isLayer = getIsLayer();

  useEffect(() => {
    if (currentRule === undefined) return;
    setCorrect(currentRule.correct);
  }, [currentRule]);

  const handleCorrectChange = () => {
    const activityClone: IActivity = clone(currentActivity);
    const updatedRule = { ...currentRule, correct: !correct };
    const ruleToUpdate: IActivity = activityClone.authoring.rules.find(
      (rule: any) => rule.id === updatedRule.id,
    );
    ruleToUpdate.correct = !correct;
    dispatch(setCurrentRule({ currentRule: updatedRule }));
    setCorrect(!correct);
    debounceSaveChanges(activityClone);
  };

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
    dispatch(setCurrentRule({ currentRule: newCorrectRule }));
    debounceSaveChanges(activityClone);
  };

  const handleAddIncorrectRule = async () => {
    const { payload: newIncorrectRule } = await dispatch<any>(
      createIncorrectRule({ isDefault: false }),
    );
    const activityClone: IActivity = clone(currentActivity);
    activityClone.authoring.rules.push(newIncorrectRule);
    dispatch(setCurrentRule({ currentRule: newIncorrectRule }));
    debounceSaveChanges(activityClone);
  };

  const handleDeleteRule = () => {
    const activityClone: IActivity = clone(currentActivity);
    const indexToDelete = activityClone.authoring.rules.findIndex(
      (rule: any) => rule.id === currentRule.id,
    );
    if (indexToDelete !== -1) {
      activityClone.authoring.rules.splice(indexToDelete, 1);
      const prevRule = activityClone.authoring.rules[indexToDelete - 1];
      const nextRule = activityClone.authoring.rules[indexToDelete + 1];
      dispatch(setCurrentRule({ currentRule: prevRule !== undefined ? prevRule : nextRule }));
      debounceSaveChanges(activityClone);
    }
  };

  return (
    <>
      <section
        id="aa-bottom-panel"
        className={`aa-panel bottom-panel${panelState['bottom'] ? ' open' : ''}`}
        style={{
          left: panelState['left'] ? PANEL_SIDE_WIDTH : 0,
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
          bottom: panelState['bottom']
            ? 0
            : `calc(-${document.getElementById('aa-bottom-panel')?.clientHeight}px + 39px)`,
        }}
      >
        <div className="aa-panel-inner">
          <div className="aa-panel-section-title-bar">
            <div className="aa-panel-section-title pl-2">
              <span className="title">rule editor</span>
              {currentRule && !isLayer && (
                <span className="ruleName">
                  {currentRule.default && currentRule.correct && (
                    <i className="fa fa-check-circle mr-1 text-muted align-middle" />
                  )}
                  {currentRule.default && !currentRule.correct && (
                    <i className="fa fa-times-circle mr-1 text-muted align-middle" />
                  )}
                  {currentRule.name}
                </span>
              )}
            </div>
            <div className="aa-panel-section-controls d-flex justify-content-center align-items-center">
              {currentRule && !isLayer && (
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
                  {!currentRule.default && (
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
                          onClick={() => handleDeleteRule()}
                        >
                          <i className="fa fa-trash-alt" />
                        </button>
                      </span>
                    </OverlayTrigger>
                  )}
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
                  <div className="dropdown">
                    <button
                      className={`dropdown-toggle btn btn-link p-0 ${
                        currentRule?.default ? 'ml-3' : 'ml-1'
                      }`}
                      type="button"
                      id={`bottom-panel-add-context-trigger`}
                      data-toggle="dropdown"
                      aria-haspopup="true"
                      aria-expanded="false"
                      onClick={(e) => {
                        ($(`#bottom-panel-add-context-trigger`) as any).dropdown('toggle');
                      }}
                    >
                      <i className="fa fa-plus" />
                    </button>
                    <div
                      id={`bottom-panel-add-context-menu`}
                      className="dropdown-menu"
                      aria-labelledby={`bottom-panel-add-context-trigger`}
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
                        onClick={(e) => {
                          handleAddIncorrectRule();
                        }}
                      >
                        <i className="fa fa-times mr-2" /> New Incorrect Rule
                      </button>
                    </div>
                  </div>
                </OverlayTrigger>
              )}
              <button className="btn btn-link p-0 ml-1" onClick={() => onToggle()}>
                {panelState['bottom'] && <i className="fa fa-angle-down" />}
                {!panelState['bottom'] && <i className="fa fa-angle-right" />}
              </button>
            </div>
          </div>
          {children}
        </div>
      </section>
    </>
  );
};
