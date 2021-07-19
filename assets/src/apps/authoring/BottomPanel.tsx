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
              {currentRule && <span className="ruleName">{currentRule.name}</span>}
            </div>
            <div className="aa-panel-section-controls d-flex justify-content-center align-items-center">
              {currentRule && (
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
                      <button className="btn btn-link p-0 ml-3">
                        <i className="fa fa-trash-alt" />
                      </button>
                    </span>
                  </OverlayTrigger>
                </>
              )}
              <OverlayTrigger
                placement="top"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    New Rule
                  </Tooltip>
                }
              >
                <span>
                  <button className="btn btn-link p-0 ml-1">
                    <i className="fa fa-plus" />
                  </button>
                </span>
              </OverlayTrigger>
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
