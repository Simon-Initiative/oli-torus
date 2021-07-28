import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import ConditionsBlock from './ConditionsBlock';

export const findConditionById = (id: string, conditions: any[]) => {
  let found = conditions.find((condition) => condition.id === id);
  if (!found) {
    // check if any of the conditions are blocks of any or all
    const blocks = conditions.filter((condition) => condition.all || condition.any);
    if (blocks.length > 0) {
      for (let i = 0; i < blocks.length; i++) {
        found = findConditionById(id, blocks[i].any || blocks[i].all);
        if (found) {
          break;
        }
      }
    }
  }
  return found || null;
};

export const forEachCondition = (conditions: any[], callback: (condition: any) => void) => {
  // clone so that callback can modify the original
  const cloneConditions = clone(conditions);
  for (let i = 0; i < cloneConditions.length; i++) {
    const condition = cloneConditions[i];
    callback(condition);
    if (condition.all || condition.any) {
      const isAll = !!condition.all;
      const type = isAll ? 'all' : 'any';
      condition[type] = forEachCondition(condition[type], callback);
    }
  }
  return cloneConditions;
};

export const deleteConditionById = (id: string, conditions: any[]) => {
  const cloneConditions = clone(conditions);
  // first check if it is one of this level's conditions
  const condition = cloneConditions.find((condition: any) => condition.id === id);
  if (condition) {
    return cloneConditions.filter((condition: any) => condition.id !== id);
  }
  return forEachCondition(cloneConditions, (condition) => {
    if (condition.all || condition.any) {
      const isAll = !!condition.all;
      const type = isAll ? 'all' : 'any';
      condition[type] = deleteConditionById(id, condition[type]);
    }
  });
};

const ConditionsBlockEditor = (props: any) => {
  const { type, rootConditions, onChange } = props;

  const [blockType, setBlockType] = useState<'any' | 'all'>(type);
  const [conditions, setConditions] = useState<any[]>(rootConditions || []);
  console.log(
    '🚀 > file: ConditionsBlockEditor.tsx > line 12 > ConditionsBlockEditor > conditions',
    conditions,
  );

  useEffect(() => {
    console.log('CONDITIONS BLOCK ED', { type, rootConditions });
    setBlockType(type);
    setConditions(rootConditions || []);
  }, [type, rootConditions]);

  useEffect(() => {
    console.log('CONDITIONS/BT CHANGE EFFECT', { blockType, conditions });
    onChange({ [blockType]: conditions });
  }, [conditions, blockType]);

  const handleBlockTypeChange = () => {
    setBlockType(blockType === 'all' ? 'any' : 'all');
  };

  const handleAddCondition = () => {
    // todo: support adding any/all sub chains?
    const newCondition = {
      id: `c:${guid()}`,
      fact: 'stage.',
      operator: 'equal',
      value: '',
    };
    setConditions([...conditions, newCondition]);
  };

  const handleAddConditionBlock = (newType: 'any' | 'all' = 'any') => {
    const block = {
      id: `b:${guid()}`,
      [newType]: [
        {
          id: `c:${guid()}`,
          fact: 'stage.',
          operator: 'equal',
          value: '',
        },
      ],
    };
    setConditions([...conditions, block]);
  };

  const handleDeleteCondition = (condition: any) => {
    const updatedConditions = deleteConditionById(condition.id, conditions);
    console.log('[handleDeleteCondition]', { condition, updatedConditions });
    setConditions(updatedConditions);
  };

  const handleConditionItemChange = (condition: any, changes: any) => {
    const updatedConditions = forEachCondition(conditions, (c: any) => {
      if (c.id === condition.id) {
        Object.assign(c, changes);
      }
    });
    console.log('[handleConditionItemChange]', { condition, updatedConditions });
    setConditions(updatedConditions);
  };

  const handleSubBlockChange = (condition: any, changes: any) => {
    console.log('[handleSubBlockChange]', { condition, changes });
    /* const index = conditions.indexOf(condition);
    if (index !== -1) {
      const clone = [...conditions];
      clone[index] = changes;
      setConditions(clone);
    } */
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
              <div className="d-flex align-items-center flex-wrap">
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
              <ConditionsBlock
                type={type}
                defaultConditions={conditions}
                onChange={handleSubBlockChange}
                onItemChange={handleConditionItemChange}
                onDeleteCondition={handleDeleteCondition}
              />
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
