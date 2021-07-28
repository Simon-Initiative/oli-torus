import React from 'react';
import ConditionItemEditor from './ConditionItemEditor';

const ConditionsBlock = (props: any) => {
  const { type, defaultConditions, onChange, onItemChange, onDeleteCondition } = props;

  return (
    <div className="">
      {defaultConditions.map((condition: any, index: number) =>
        condition.all || condition.any ? (
          <ConditionsBlock
            key={condition.id || `cb-${index}`}
            type={type}
            defaultConditions={condition.all || condition.any || []}
            onChange={onChange}
            onItemChange={onItemChange}
            onDeleteCondition={onDeleteCondition}
          />
        ) : (
          <ConditionItemEditor
            key={condition.id || `ci-${index}`}
            condition={condition}
            onChange={(changes: any) => {
              onItemChange(condition, changes);
            }}
            onDelete={() => onDeleteCondition(condition)}
          />
        ),
      )}

      {/* {defaultConditions.map((condition: any, index: number) => (
        <Fragment key={`${guid()}`}>
          {(condition && condition.all) || condition.any ? (
            <ConditionsBlock
              key={`${guid()}`}
              type={condition.all ? 'all' : 'any'}
              defaultConditions={condition.all || condition.any || []}
              onChange={onChange()}
            />
          ) : (
            <ConditionItemEditor
              key={`${guid()}`}
              condition={condition}
              onChange={(changes: any) => {
                handleConditionItemChange(condition, changes);
              }}
              onDelete={() => handleDeleteCondition(condition)}
            />
          )}
        </Fragment>
      ))} */}

      {/* <div className="aa-condition-header d-flex justify-content-between align-items-center">
        <div>CONDITIONS</div>
        <div>
          <OverlayTrigger
            placement="top"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Delete Group
              </Tooltip>
            }
          >
            <span>
              <button className="btn btn-link p-0">
                <i className="fa fa-trash-alt" />
              </button>
            </span>
          </OverlayTrigger>
          <OverlayTrigger
            placement="top"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                New Condition
              </Tooltip>
            }
          >
            <span>
              <button className="btn btn-link p-0 ml-1">
                <i className="fa fa-plus" />
              </button>
            </span>
          </OverlayTrigger>
        </div>
      </div>
      <div className="d-flex align-items-center flex-wrap">
        <span className="mr-2">If</span>
        <div className="form-check form-check-inline mr-1">
          <input
            className="form-check-input"
            type="radio"
            name={`anyAllToggle-${uuid}`}
            id={`anyCondition-${uuid}`}
            defaultChecked={type === 'any'}
            onChange={() => handleBlockTypeChange()}
          />
          <label className="form-check-label" htmlFor={`anyCondition-${uuid}`}>
            ANY
          </label>
        </div>
        <div className="form-check form-check-inline mr-2">
          <input
            className="form-check-input"
            type="radio"
            name={`anyAllToggle-${uuid}`}
            id={`allCondition-${uuid}`}
            defaultChecked={type === 'all'}
            onChange={() => handleBlockTypeChange()}
          />
          <label className="form-check-label" htmlFor={`allCondition-${uuid}`}>
            ALL
          </label>
        </div>
        of the following conditions are met
      </div>
      {defaultConditions.map((condition: any, index: number) => (
        <Fragment key={`${guid()}`}>
          {(condition && condition.all) || condition.any ? (
            <ConditionsBlock
              key={`${guid()}`}
              type={condition.all ? 'all' : 'any'}
              defaultConditions={condition.all || condition.any || []}
              onChange={onChange()}
            />
          ) : (
            <ConditionItemEditor
              key={`${guid()}`}
              condition={condition}
              onChange={(changes: any) => {
                handleConditionItemChange(condition, changes);
              }}
              onDelete={() => handleDeleteCondition(condition)}
            />
          )}
        </Fragment>
      ))} */}
    </div>
  );
};

export default ConditionsBlock;
