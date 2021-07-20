import React, { useEffect, useCallback } from 'react';
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

const AdaptiveRulesList: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const rules = currentActivity?.authoring.rules || [];

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

  useEffect(() => {
    if (currentRule !== undefined) return;
    rules.length > 0
      ? dispatch(setCurrentRule({ currentRule: rules[0] }))
      : dispatch(setCurrentRule({ currentRule: undefined }));
  }, [currentActivity]);

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
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup className="aa-rules-list" as="ol">
          {currentRule &&
            rules.map((rule: any, index: any) => (
              <ListGroup.Item
                className="aa-rules-list-item"
                as="li"
                key={rule.id}
                active={rule.id === currentRule?.id}
                onClick={() => handleSelectRule(rule)}
              >
                {rule.default && rule.correct && (
                  <i className="fa fa-check-circle mr-1 text-muted align-middle" />
                )}
                {rule.default && !rule.correct && (
                  <i className="fa fa-times-circle mr-1 text-muted align-middle" />
                )}
                {rule.name}
              </ListGroup.Item>
            ))}
          {!currentRule && <span>No screen selected</span>}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AdaptiveRulesList;
