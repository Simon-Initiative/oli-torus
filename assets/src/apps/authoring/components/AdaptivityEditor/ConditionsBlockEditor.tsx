import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { ConditionProperties } from 'json-rules-engine';
import { isEqual } from 'lodash';
import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import ConditionItemEditor from './ConditionItemEditor';

export interface JanusConditionProperties extends ConditionProperties {
  id: string;
  type?: CapiVariableTypes;
}

type JanusNestedCondition = JanusConditionProperties | JanusTopLevelCondition;
type JanusAllConditions = { id: string; all: JanusNestedCondition[] };
type JanusAnyConditions = { id: string; any: JanusNestedCondition[] };
export type JanusTopLevelCondition = JanusAllConditions | JanusAnyConditions;
type AnyOrAll = 'any' | 'all';

export const findConditionById = (
  id: string,
  conditions: JanusNestedCondition[] | JanusTopLevelCondition[],
): JanusNestedCondition | null => {
  let found = conditions.find((condition) => condition.id === id) || null;
  if (!found) {
    // check if any of the conditions are blocks of any or all
    const blocks = conditions.filter(
      (condition) => (condition as JanusAllConditions).all || (condition as JanusAnyConditions).any,
    );
    if (blocks.length > 0) {
      for (let i = 0; i < blocks.length; i++) {
        found = findConditionById(
          id,
          (blocks[i] as JanusAnyConditions).any || (blocks[i] as JanusAllConditions).all,
        );
        if (found) {
          break;
        }
      }
    }
  }
  return found || null;
};

export const forEachCondition = (
  conditions: JanusNestedCondition[] | JanusTopLevelCondition[],
  callback: (condition: JanusNestedCondition) => void,
) => {
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

export const deleteConditionById = (
  id: string,
  conditions: JanusNestedCondition[] | JanusTopLevelCondition[],
) => {
  const cloneConditions = clone(conditions);
  // first check if it is one of this level's conditions
  const condition = cloneConditions.find((condition: JanusNestedCondition) => condition.id === id);
  if (condition) {
    return cloneConditions.filter((condition: JanusNestedCondition) => condition.id !== id);
  }
  return forEachCondition(cloneConditions, (condition) => {
    if ((condition as JanusAllConditions).all || (condition as JanusAnyConditions).any) {
      const isAll = !!(condition as JanusAllConditions).all;
      if (isAll) {
        (condition as JanusAllConditions).all = deleteConditionById(
          id,
          (condition as JanusAllConditions).all,
        );
      } else {
        (condition as JanusAnyConditions).any = deleteConditionById(
          id,
          (condition as JanusAnyConditions).any,
        );
      }
    }
  });
};

interface CondtionsBlockEditorProps {
  id: string;
  type: AnyOrAll;
  index: number;
  rootConditions: JanusNestedCondition[];
  onChange: (changes: Partial<JanusTopLevelCondition>) => void;
}

const ConditionsBlockEditor: React.FC<CondtionsBlockEditorProps> = (props) => {
  const { id, type, index, rootConditions, onChange } = props;
  const [blockType, setBlockType] = useState<AnyOrAll>(type);
  const [conditions, setConditions] = useState<JanusNestedCondition[]>(rootConditions || []);
  const [loopIndex, setLoopIndex] = useState<number>(index);

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
      type: CapiVariableTypes.STRING,
      fact: 'stage.',
      operator: 'equal',
      value: '',
    };
    setConditions([...conditions, newCondition]);
  };

  const handleAddConditionBlock = (newType: AnyOrAll = 'any') => {
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
    } as JanusTopLevelCondition;
    setConditions([...conditions, block]);
  };

  const handleDeleteCondition = (condition: Partial<JanusNestedCondition>, loopIndex?: number) => {
    if (condition.id === 'root') {
      const empty: JanusNestedCondition[] = [];
      setConditions(empty);
      if (loopIndex && loopIndex > 0) {
        return onChange({});
      } else {
        return onChange({ [blockType]: empty });
      }
    }

    const updatedConditions = deleteConditionById(condition.id as string, conditions);
    setConditions(updatedConditions);
  };

  const handleConditionItemChange = (
    condition: JanusConditionProperties,
    changes: Partial<JanusConditionProperties>,
  ) => {
    const updatedConditions = forEachCondition(conditions, (c) => {
      if (c.id === condition.id) {
        if (changes.fact) {
          (c as JanusConditionProperties).fact = changes.fact;
        }
        if (changes.type) {
          (c as JanusConditionProperties).type = changes.type;
        }
        if (changes.operator) {
          (c as JanusConditionProperties).operator = changes.operator;
        }
        if (changes.value !== undefined) {
          (c as JanusConditionProperties).value = changes.value;
        }
      }
    });
    console.log('[handleConditionItemChange]', { changes, condition, updatedConditions });
    setConditions(updatedConditions);
  };

  const handleSubBlockChange = (condition: any, changes: any) => {
    const updatedConditions = forEachCondition(conditions, (c: any) => {
      if (c.id === condition.id) {
        // changes will be either any or all because that could change
        if (changes.all) {
          delete c.any;
          c.all = changes.all;
        } else {
          delete c.all;
          c.any = changes.any;
        }
      }
    });
    console.log('[handleSubBlockChange]', { condition, changes, updatedConditions });
    setConditions(updatedConditions);
  };

  const AddConditionContextMenu = () => (
    <>
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
    </>
  );

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
        <AddConditionContextMenu />
      </div>
      <div className="d-flex flex-column w-100">
        <div className="aa-condition border rounded p-2 mt-4">
          <div className="aa-condition-header d-flex justify-content-between align-items-center">
            <div>CONDITIONS</div>
            <div>
              {loopIndex !== 0 && (
                <OverlayTrigger
                  placement="top"
                  delay={{ show: 150, hide: 150 }}
                  overlay={
                    <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                      {`Delete Group`}
                    </Tooltip>
                  }
                >
                  <span>
                    <button
                      className="btn btn-link p-0"
                      onClick={() => handleDeleteCondition({ id: 'root' }, loopIndex)}
                    >
                      <i className="fa fa-trash-alt" />
                    </button>
                  </span>
                </OverlayTrigger>
              )}
              {loopIndex === 0 && conditions.length >= 1 && (
                <OverlayTrigger
                  placement="top"
                  delay={{ show: 150, hide: 150 }}
                  overlay={
                    <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                      {`Delete ${loopIndex === 0 ? 'All' : 'Group'}`}
                    </Tooltip>
                  }
                >
                  <span>
                    <button
                      className="btn btn-link p-0"
                      onClick={() => handleDeleteCondition({ id: 'root' })}
                    >
                      <i className="fa fa-trash-alt" />
                    </button>
                  </span>
                </OverlayTrigger>
              )}
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
                  className="dropdown-toggle btn btn-link p-0 ml-1"
                  type="button"
                  id={`add-condition-${id}-context-trigger-${index}`}
                  data-toggle="dropdown"
                  aria-haspopup="true"
                  aria-expanded="false"
                  onClick={(e) => {
                    // e.stopPropagation();
                    ($(`#add-condition-${id}-context-trigger-${index}`) as any).dropdown('toggle');
                  }}
                >
                  <i className="fa fa-plus" />
                </button>
              </OverlayTrigger>
              <div
                id={`add-condition-${id}-context-menu`}
                className="dropdown-menu"
                aria-labelledby={`add-condition-${id}-context-trigger-${index}`}
              >
                <AddConditionContextMenu />
              </div>
            </div>
          </div>
          <div className="d-flex align-items-center flex-wrap">
            <span className="mr-2">If</span>
            <div className="form-check form-check-inline mr-1">
              <input
                className="form-check-input"
                type="radio"
                name={`anyAllToggle-${id}`}
                id={`anyCondition-${id}`}
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
                name={`anyAllToggle-${id}`}
                id={`allCondition-${id}`}
                defaultChecked={blockType === 'all'}
                onChange={() => handleBlockTypeChange()}
              />
              <label className="form-check-label" htmlFor="allCondition-root">
                ALL
              </label>
            </div>
            of the following conditions are met
          </div>
          {conditions.length <= 0 && (
            <div className="mt-2 text-danger">No conditions. This rule will always fire.</div>
          )}
          {conditions.map((condition, index) =>
            (condition as JanusAllConditions).all || (condition as JanusAnyConditions).any ? (
              <ConditionsBlockEditor
                key={condition.id || `cb-${index}`}
                id={condition.id || `cb-${index}`}
                type={(condition as JanusAllConditions).all ? 'all' : 'any'}
                rootConditions={
                  (condition as JanusAllConditions).all ||
                  (condition as JanusAnyConditions).any ||
                  []
                }
                onChange={(changes) =>
                  handleSubBlockChange(condition as JanusTopLevelCondition, changes)
                }
                index={loopIndex}
              />
            ) : (
              <ConditionItemEditor
                key={condition.id || `ci-${index}`}
                parentIndex={index}
                condition={condition as JanusConditionProperties}
                onChange={(changes) =>
                  handleConditionItemChange(condition as JanusConditionProperties, changes)
                }
                onDelete={() => handleDeleteCondition(condition)}
              />
            ),
          )}
        </div>
      </div>
    </div>
  );
};

export default ConditionsBlockEditor;
