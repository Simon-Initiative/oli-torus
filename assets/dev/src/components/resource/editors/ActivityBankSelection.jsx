import React from 'react';
import { LogicBuilder } from 'components/logic/LogicBuilder';
import { TextInput } from 'components/common/TextInput';
import * as Bank from 'data/content/bank';
export const ActivityBankSelection = (props) => {
    const { selection, onChange, editMode } = props;
    const onChangeCount = (countString) => {
        let count;
        try {
            count = parseInt(countString, 10);
        }
        catch (e) {
            count = 1;
        }
        if (isNaN(count) || count <= 0) {
            count = 1;
        }
        const selection = Object.assign({}, props.selection, { count });
        onChange(selection);
    };
    const onChangeLogic = (logic) => {
        if (logic.conditions !== null &&
            (logic.conditions.operator === Bank.ClauseOperator.all ||
                logic.conditions.operator === Bank.ClauseOperator.any)) {
            if (logic.conditions.children.length === 0) {
                const selection = Object.assign({}, props.selection, { logic: { conditions: null } });
                onChange(selection);
                return;
            }
            else if (logic.conditions.children.length === 1) {
                const selection = Object.assign({}, props.selection, {
                    logic: { conditions: logic.conditions.children[0] },
                });
                onChange(selection);
                return;
            }
        }
        const selection = Object.assign({}, props.selection, {
            logic,
        });
        onChange(selection);
    };
    // This add implementation allows only expressions to be added, but will implicitly
    // insert an "all" clause to wrap a colleciton of expressions.
    const onAdd = () => {
        const expression = {
            fact: Bank.Fact.objectives,
            operator: Bank.ExpressionOperator.contains,
            value: [],
        };
        if (selection.logic.conditions === null) {
            const conditions = expression;
            const logic = Object.assign({}, selection.logic, { conditions });
            onChange(Object.assign({}, selection, { logic }));
        }
        else if (selection.logic.conditions.operator === Bank.ClauseOperator.all ||
            selection.logic.conditions.operator === Bank.ClauseOperator.any) {
            const conditions = Object.assign({}, selection.logic.conditions, {
                children: [...selection.logic.conditions.children, expression],
            });
            const logic = Object.assign({}, selection.logic, { conditions });
            onChange(Object.assign({}, selection, { logic }));
        }
        else {
            const conditions = {
                operator: Bank.ClauseOperator.all,
                children: [selection.logic.conditions, expression],
            };
            const logic = Object.assign({}, selection.logic, { conditions });
            onChange(Object.assign({}, selection, { logic }));
        }
    };
    return (<div id={props.selection.id} className="activity-bank-selection">
      <div className="label mb-3">Activity Bank Selection</div>
      <div className="d-flex justify-items-start mb-4">
        <div className="mr-3">Number to select:</div>
        <div className="count-input">
          <TextInput onEdit={onChangeCount} type="number" editMode={editMode} value={selection.count.toString()} label="Number of activities"/>
        </div>
      </div>
      <div className="mb-3">Criteria for selection:</div>
      <LogicBuilder allowText={false} editMode={editMode} logic={selection.logic} onChange={onChangeLogic} onRegisterNewObjective={props.onRegisterNewObjective} onRegisterNewTag={props.onRegisterNewTag} allObjectives={props.allObjectives} allTags={props.allTags} projectSlug={props.projectSlug} editorMap={props.editorMap} onRemove={() => true}/>
      <button className="btn btn-primary btn-sm" onClick={onAdd}>
        Add Expression
      </button>
    </div>);
};
//# sourceMappingURL=ActivityBankSelection.jsx.map