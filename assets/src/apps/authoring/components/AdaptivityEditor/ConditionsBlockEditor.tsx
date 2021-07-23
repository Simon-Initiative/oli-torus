import React, { Fragment, useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';
import ConditionItemEditor from './ConditionItemEditor';

const ConditionsBlockEditor = (props: any) => {
  const { type, defaultConditions, onChange } = props;

  const [blockType, setBlockType] = useState<'any' | 'all'>(type);
  const [conditions, setConditions] = useState<any[]>(defaultConditions || []);

  useEffect(() => {
    setBlockType(type);
    setConditions(defaultConditions || []);
  }, [type, defaultConditions]);

  useEffect(() => {
    onChange({ [blockType]: conditions });
  }, [conditions, blockType]);

  const handleBlockTypeChange = () => {
    setBlockType(blockType === 'all' ? 'any' : 'all');
  };

  const handleAddCondition = async () => {
    // todo: support adding any/all sub chains?
    const newCondition = {
      fact: 'stage.',
      operator: 'equal',
      value: '',
    };
    setConditions([...conditions, newCondition]);
  };

  const handleAddConditionBlock = async (newType: 'any' | 'all' = 'any') => {
    const block = {
      [newType]: [
        {
          fact: 'stage.',
          operator: 'equal',
          value: '',
        },
      ],
    };
    setConditions([...conditions, block]);
  };

  const handleDeleteCondition = async (condition: any) => {
    const temp = conditions.filter((c) => c !== condition);
    setConditions(temp);
  };

  const handleConditionItemChange = (condition: any, changes: any) => {
    const index = conditions.indexOf(condition);
    if (index !== -1) {
      const clone = [...conditions];
      const updatedCondition = { ...condition, ...changes };
      clone[index] = updatedCondition;
      setConditions(clone);
    }
  };

  const handleSubBlockChange = (condition: any, changes: any) => {
    const index = conditions.indexOf(condition);
    if (index !== -1) {
      const clone = [...conditions];
      clone[index] = changes;
      setConditions(clone);
    }
  };

  const ConditionsBlock = (props: any) => {
    const { type, defaultConditions, onChange } = props;
    const uuid = guid();

    return (
      <div className="aa-condition border rounded p-2 mt-4">
        <div className="aa-condition-header d-flex justify-content-between align-items-center">
          <div>CONDITIONS</div>
          {/* <div>
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
              </div> */}
        </div>
        <div className="d-flex align-items-center">
          <span className="mr-2">If</span>
          <div className="form-check form-check-inline mr-1">
            <input
              className="form-check-input"
              type="radio"
              name={`anyAllToggle-${uuid}`}
              id={`anyCondition-${uuid}`}
              defaultChecked={type === 'any'}
              onChange={(changes: any) => handleSubBlockChange(defaultConditions, changes)}
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
              onChange={(changes: any) => handleSubBlockChange(defaultConditions, changes)}
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
                onChange={(changes: any) => handleSubBlockChange(condition, changes)}
              />
            ) : (
              <ConditionItemEditor
                key={`${guid()}`}
                condition={condition}
                onChange={(changes: any) => {
                  handleConditionItemChange(condition, changes);
                }}
              />
            )}
          </Fragment>
        ))}
      </div>
    );
  };

  return (
    <div className="aa-conditions d-flex w-100">
      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            New Condition
          </Tooltip>
        }
      >
        <button
          className="dropdown-toggle aa-add-button btn btn-primary btn-sm mr-3"
          type="button"
          id={`rules-list-add-context-trigger`}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
          onClick={(e) => {
            ($(`#cb-editor-add-context-trigger`) as any).dropdown('toggle');
          }}
        >
          <i className="fa fa-plus" />
        </button>
      </OverlayTrigger>
      <div
        id={`cb-editor-add-context-menu`}
        className="dropdown-menu"
        aria-labelledby={`cb-editor-add-context-trigger`}
      >
        <button
          className="dropdown-item"
          onClick={() => {
            handleAddCondition();
          }}
        >
          <i className="fa fa-plus mr-2" /> Single Condition
        </button>
        <button
          className="dropdown-item"
          onClick={() => {
            handleAddConditionBlock('any');
          }}
        >
          <i className="fa fa-plus mr-2" /> Any Block
        </button>
        <button
          className="dropdown-item"
          onClick={() => {
            handleAddConditionBlock('all');
          }}
        >
          <i className="fa fa-plus mr-2" /> All Block
        </button>
      </div>
      <div className="d-flex flex-column w-100">
        {conditions.length === 0 && <div>No conditions. This rule will always fire.</div>}
        {conditions.length > 0 && (
          <div>
            <div className="aa-condition border rounded p-2 mt-4">
              <div className="aa-condition-header d-flex justify-content-between align-items-center">
                <div>CONDITIONS</div>
                {/* <div>
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
              </div> */}
              </div>
              <div className="d-flex align-items-center">
                <span className="mr-2">If</span>
                <div className="form-check form-check-inline mr-1">
                  <input
                    className="form-check-input"
                    type="radio"
                    name="anyAllToggle-root"
                    id="anyCondition-root"
                    defaultChecked={blockType === 'any'}
                    onChange={() => handleBlockTypeChange()}
                  />
                  <label className="form-check-label" htmlFor="anyCondition-root">
                    ANY
                  </label>
                </div>
                <div className="form-check form-check-inline mr-2">
                  <input
                    className="form-check-input"
                    type="radio"
                    name="anyAllToggle-root"
                    id="allCondition-root"
                    defaultChecked={blockType === 'all'}
                    onChange={() => handleBlockTypeChange()}
                  />
                  <label className="form-check-label" htmlFor="allCondition-root">
                    ALL
                  </label>
                </div>
                of the following conditions are met
              </div>
              {conditions.map((condition: any, index: number) => (
                <Fragment key={`${guid()}`}>
                  {condition.all || condition.any ? (
                    <ConditionsBlock
                      key={`${guid()}`}
                      type={condition.all ? 'all' : 'any'}
                      defaultConditions={condition.all || condition.any || []}
                      onChange={(changes: any) => handleSubBlockChange(condition, changes)}
                    />
                  ) : (
                    <ConditionItemEditor
                      key={`${guid()}`}
                      condition={condition}
                      onChange={(changes: any) => {
                        handleConditionItemChange(condition, changes);
                      }}
                    />
                  )}
                </Fragment>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>

    // <Fragment>
    //   <Header attached="top">
    //     <Grid>
    //       <Grid.Column floated="left" width={5}>
    //         Conditions
    //       </Grid.Column>
    //       <Grid.Column floated="right" width={5}>
    //         Any{' '}
    //         <Checkbox
    //           toggle
    //           defaultChecked={blockType === 'all'}
    //           onChange={handleBlockTypeChange}
    //         />{' '}
    //         All
    //       </Grid.Column>
    //     </Grid>
    //   </Header>
    //   <Segment attached>
    //     <Button.Group>
    //       <Button
    //         onClick={handleAddCondition}
    //         labelPosition="left"
    //         icon="plus"
    //         content="Single Condition"
    //       />
    //       <Button.Or />
    //       <Button
    //         onClick={() => {
    //           handleAddConditionBlock('any');
    //         }}
    //         content="Any Block"
    //       />
    //       <Button.Or />
    //       <Button
    //         onClick={() => {
    //           handleAddConditionBlock('all');
    //         }}
    //         content="All Block"
    //       />
    //     </Button.Group>

    //     <List divided verticalAlign="middle">
    //       {conditions.map((condition, index) => (
    //         <List.Item key={`${index}`}>
    //           <List.Content floated="right">
    //             <Button negative onClick={() => handleDeleteCondition(condition)}>
    //               Delete
    //             </Button>
    //           </List.Content>
    //           {condition.all || condition.any ? (
    //             <ConditionsBlockEditor
    //               type={condition.all ? 'all' : 'any'}
    //               defaultConditions={condition.all || condition.any || []}
    //               onChange={(changes: any) => handleSubBlockChange(condition, changes)}
    //             />
    //           ) : (
    //             <ConditionItemEditor
    //               condition={condition}
    //               onChange={(changes: any) => {
    //                 handleConditionItemChange(condition, changes);
    //               }}
    //             />
    //           )}
    //         </List.Item>
    //       ))}
    //     </List>
    //   </Segment>
    // </Fragment>
  );
};

export default ConditionsBlockEditor;
