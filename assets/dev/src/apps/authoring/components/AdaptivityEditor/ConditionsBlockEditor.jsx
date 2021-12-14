import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { isEqual } from 'lodash';
import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import ConditionItemEditor from './ConditionItemEditor';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
export const findConditionById = (id, conditions) => {
    let found = conditions.find((condition) => condition.id === id) || null;
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
export const forEachCondition = (conditions, callback) => {
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
export const deleteConditionById = (id, conditions) => {
    const cloneConditions = clone(conditions);
    // first check if it is one of this level's conditions
    const condition = cloneConditions.find((condition) => condition.id === id);
    if (condition) {
        return cloneConditions.filter((condition) => condition.id !== id);
    }
    return forEachCondition(cloneConditions, (condition) => {
        if (condition.all || condition.any) {
            const isAll = !!condition.all;
            if (isAll) {
                condition.all = deleteConditionById(id, condition.all);
            }
            else {
                condition.any = deleteConditionById(id, condition.any);
            }
        }
    });
};
const ConditionsBlockEditor = (props) => {
    const { id, type, index, rootConditions, onChange } = props;
    const [blockType, setBlockType] = useState(type);
    const [conditions, setConditions] = useState(rootConditions || []);
    const [loopIndex, setLoopIndex] = useState(index);
    const [showConfirmDelete, setShowConfirmDelete] = useState(false);
    const [conditionToDelete, setConditionToDelete] = useState(undefined);
    const [loopIndexToDelete, setLoopIndexToDelete] = useState(undefined);
    useEffect(() => {
        setLoopIndex(index + 1);
    }, []);
    useEffect(() => {
        /* console.log('CONDITIONS BLOCK ED', { type, rootConditions }); */
        // this is just when the props change, only do it once?
        if (type !== blockType) {
            setBlockType(type);
        }
        if (!isEqual(conditions, rootConditions)) {
            setConditions(rootConditions || []);
        }
    }, [type, rootConditions]);
    useEffect(() => {
        /* console.log('CONDITIONS/BT CHANGE EFFECT', { blockType, conditions }); */
        onChange({ [blockType]: conditions });
    }, [conditions, blockType]);
    const handleBlockTypeChange = () => {
        setBlockType(blockType === 'all' ? 'any' : 'all');
    };
    const handleAddCondition = () => {
        // todo: support adding any/all sub chains?
        const newCondition = {
            id: `c:${guid()}`,
            type: CapiVariableTypes.STRING,
            fact: 'stage.',
            operator: 'equal',
            value: '',
        };
        setConditions([...conditions, newCondition]);
    };
    const handleAddConditionBlock = (newType = 'any') => {
        const block = {
            id: `b:${guid()}`,
            [newType]: [
                {
                    id: `c:${guid()}`,
                    fact: 'stage.',
                    type: CapiVariableTypes.STRING,
                    operator: 'equal',
                    value: '',
                },
            ],
        };
        setConditions([...conditions, block]);
    };
    const handleDeleteCondition = (condition, loopIndex) => {
        if (condition.id === 'root') {
            const empty = [];
            setConditions(empty);
            if (loopIndex && loopIndex > 0) {
                return onChange({});
            }
            else {
                return onChange({ [blockType]: empty });
            }
        }
        const updatedConditions = deleteConditionById(condition.id, conditions);
        setConditions(updatedConditions);
    };
    const handleConditionItemChange = (condition, changes) => {
        const updatedConditions = forEachCondition(conditions, (c) => {
            if (c.id === condition.id) {
                if (changes.fact) {
                    c.fact = changes.fact;
                }
                if (changes.type) {
                    c.type = changes.type;
                }
                if (changes.operator) {
                    c.operator = changes.operator;
                }
                if (changes.value !== undefined) {
                    c.value = changes.value;
                }
            }
        });
        /* console.log('[handleConditionItemChange]', { changes, condition, updatedConditions }); */
        setConditions(updatedConditions);
    };
    const handleSubBlockChange = (condition, changes) => {
        const updatedConditions = forEachCondition(conditions, (c) => {
            if (c.id === condition.id) {
                // changes will be either any or all because that could change
                if (changes.all) {
                    delete c.any;
                    c.all = changes.all;
                }
                else {
                    delete c.all;
                    c.any = changes.any;
                }
            }
        });
        /* console.log('[handleSubBlockChange]', { condition, changes, updatedConditions }); */
        setConditions(updatedConditions);
    };
    const AddConditionContextMenu = () => (<>
      <button className="dropdown-item" onClick={() => {
            handleAddCondition();
        }}>
        <i className="fa fa-plus mr-2"/> Single Condition
      </button>
      <button className="dropdown-item" onClick={() => {
            handleAddConditionBlock('any');
        }}>
        <i className="fa fa-plus mr-2"/> Any Block
      </button>
      <button className="dropdown-item" onClick={() => {
            handleAddConditionBlock('all');
        }}>
        <i className="fa fa-plus mr-2"/> All Block
      </button>
    </>);
    return (<div className="aa-conditions d-flex w-100">
      <OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            New Condition
          </Tooltip>}>
        <button className="dropdown-toggle aa-add-button btn btn-primary btn-sm mr-3" type="button" id={`rules-list-add-context-trigger`} data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" onClick={() => {
            $(`#cb-editor-add-context-trigger`).dropdown('toggle');
        }}>
          <i className="fa fa-plus"/>
        </button>
      </OverlayTrigger>
      <div id={`cb-editor-add-context-menu`} className="dropdown-menu" aria-labelledby={`cb-editor-add-context-trigger`}>
        <AddConditionContextMenu />
      </div>
      <div className="d-flex flex-column w-100">
        <div className="aa-condition border rounded p-2 mt-4">
          <div className="aa-condition-header d-flex justify-content-between align-items-center">
            <div>CONDITIONS</div>
            <div>
              {loopIndex !== 0 && (<OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                      {`Delete Group`}
                    </Tooltip>}>
                  <span>
                    <button className="btn btn-link p-0" onClick={() => {
                setShowConfirmDelete(true);
                setConditionToDelete({ id: 'root' });
                setLoopIndexToDelete(loopIndex);
            }}>
                      <i className="fa fa-trash-alt"/>
                    </button>
                  </span>
                </OverlayTrigger>)}
              {loopIndex === 0 && conditions.length >= 1 && (<OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                      {`Delete ${loopIndex === 0 ? 'All' : 'Group'}`}
                    </Tooltip>}>
                  <span>
                    <button className="btn btn-link p-0" onClick={() => {
                setShowConfirmDelete(true);
                setConditionToDelete({ id: 'root' });
            }}>
                      <i className="fa fa-trash-alt"/>
                    </button>
                  </span>
                </OverlayTrigger>)}
              <OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    New Condition
                  </Tooltip>}>
                <button className="dropdown-toggle btn btn-link p-0 ml-1" type="button" id={`add-condition-${id}-context-trigger-${index}`} data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" onClick={() => {
            $(`#add-condition-${id}-context-trigger-${index}`).dropdown('toggle');
        }}>
                  <i className="fa fa-plus"/>
                </button>
              </OverlayTrigger>
              <div id={`add-condition-${id}-context-menu`} className="dropdown-menu" aria-labelledby={`add-condition-${id}-context-trigger-${index}`}>
                <AddConditionContextMenu />
              </div>
            </div>
          </div>
          <div className="d-flex align-items-center flex-wrap">
            <span className="mr-2">If</span>
            <div className="form-check form-check-inline mr-1">
              <input className="form-check-input" type="radio" name={`anyAllToggle-${id}`} id={`anyCondition-${id}`} defaultChecked={blockType === 'any'} onChange={() => handleBlockTypeChange()}/>
              <label className="form-check-label" htmlFor="anyCondition-root">
                ANY
              </label>
            </div>
            <div className="form-check form-check-inline mr-2">
              <input className="form-check-input" type="radio" name={`anyAllToggle-${id}`} id={`allCondition-${id}`} defaultChecked={blockType === 'all'} onChange={() => handleBlockTypeChange()}/>
              <label className="form-check-label" htmlFor="allCondition-root">
                ALL
              </label>
            </div>
            of the following conditions are met
          </div>
          {conditions.length <= 0 && (<div className="mt-2 text-danger">No conditions. This rule will always fire.</div>)}
          {conditions.map((condition, index) => condition.all || condition.any ? (<ConditionsBlockEditor key={condition.id || `cb-${index}`} id={condition.id || `cb-${index}`} type={condition.all ? 'all' : 'any'} rootConditions={condition.all ||
                condition.any ||
                []} onChange={(changes) => handleSubBlockChange(condition, changes)} index={loopIndex}/>) : (<ConditionItemEditor key={condition.id || `ci-${index}`} parentIndex={index} condition={condition} onChange={(changes) => handleConditionItemChange(condition, changes)} onDelete={() => handleDeleteCondition(condition)}/>))}
        </div>
      </div>
      {showConfirmDelete && (<ConfirmDelete show={showConfirmDelete} elementType={`${loopIndexToDelete ? 'Condition Group' : 'All Conditions'}`} elementName={`${loopIndexToDelete ? 'this condition group' : 'all conditions'}`} deleteHandler={() => {
                handleDeleteCondition(conditionToDelete, loopIndexToDelete ? loopIndexToDelete : undefined);
                setShowConfirmDelete(false);
                setConditionToDelete(undefined);
                setLoopIndexToDelete(undefined);
            }} cancelHandler={() => {
                setShowConfirmDelete(false);
                setConditionToDelete(undefined);
                setLoopIndexToDelete(undefined);
            }}/>)}
    </div>);
};
export default ConditionsBlockEditor;
//# sourceMappingURL=ConditionsBlockEditor.jsx.map