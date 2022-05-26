import React from 'react';
import * as Immutable from 'immutable';
import { ActivityBankSelection as Selection } from 'data/content/resource';
import { LogicBuilder } from 'components/logic/LogicBuilder';
import { TextInput } from 'components/common/TextInput';
import { Tag } from 'data/content/tags';
import * as Bank from 'data/content/bank';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';

import './ActivityBankSelectionEditor.scss';

export type ActivityBankSelectionEditorProps = {
  contentItem: Selection;
  onEdit: (contentItem: Selection) => void;
  editMode: boolean;
  allObjectives: Immutable.List<Objective>;
  allTags: Immutable.List<Tag>;
  projectSlug: string;
  onRegisterNewObjective: (objective: Objective) => void;
  onRegisterNewTag: (tag: Tag) => void;
  editorMap: ActivityEditorMap;
};

export const ActivityBankSelectionEditor = (props: ActivityBankSelectionEditorProps) => {
  const { contentItem, onEdit, editMode } = props;

  const onEditCount = (countString: string) => {
    let count;

    try {
      count = parseInt(countString, 10);
    } catch (e) {
      count = 1;
    }

    if (isNaN(count) || count <= 0) {
      count = 1;
    }

    onEdit(Object.assign({}, contentItem, { count }));
  };

  const onEditLogic = (logic: Bank.Logic) => {
    if (
      logic.conditions !== null &&
      (logic.conditions.operator === Bank.ClauseOperator.all ||
        logic.conditions.operator === Bank.ClauseOperator.any)
    ) {
      if (logic.conditions.children.length === 0) {
        const selection = Object.assign({}, contentItem, { logic: { conditions: null } });
        onEdit(selection);
        return;
      } else if (logic.conditions.children.length === 1) {
        const selection = Object.assign({}, contentItem, {
          logic: { conditions: logic.conditions.children[0] },
        });
        onEdit(selection);
        return;
      }
    }

    onEdit(
      Object.assign({}, contentItem, {
        logic,
      }),
    );
  };

  // This add implementation allows only expressions to be added, but will implicitly
  // insert an "all" clause to wrap a colleciton of expressions.
  const onAdd = () => {
    const expression = {
      fact: Bank.Fact.objectives,
      operator: Bank.ExpressionOperator.contains,
      value: [],
    };

    if (contentItem.logic.conditions === null) {
      const conditions = expression;
      const logic = Object.assign({}, contentItem.logic, { conditions });
      onEdit(Object.assign({}, contentItem, { logic }));
    } else if (
      contentItem.logic.conditions.operator === Bank.ClauseOperator.all ||
      contentItem.logic.conditions.operator === Bank.ClauseOperator.any
    ) {
      const conditions = Object.assign({}, contentItem.logic.conditions, {
        children: [...contentItem.logic.conditions.children, expression],
      });
      const logic = Object.assign({}, contentItem.logic, { conditions });
      onEdit(Object.assign({}, contentItem, { logic }));
    } else {
      const conditions = {
        operator: Bank.ClauseOperator.all,
        children: [contentItem.logic.conditions, expression],
      };
      const logic = Object.assign({}, contentItem.logic, { conditions });
      onEdit(Object.assign({}, contentItem, { logic }));
    }
  };

  return (
    <div id={contentItem.id} className="activity-bank-selection">
      <div className="label mb-3">Activity Bank Selection</div>
      <div className="d-flex justify-items-start mb-4">
        <div className="mr-3">Number to select:</div>
        <div className="count-input">
          <TextInput
            onEdit={onEditCount}
            type="number"
            editMode={editMode}
            value={contentItem.count.toString()}
            label="Number of activities"
          />
        </div>
      </div>
      <div className="mb-3">Criteria for selection:</div>
      <LogicBuilder
        allowText={false}
        editMode={editMode}
        logic={contentItem.logic}
        onChange={onEditLogic}
        onRegisterNewObjective={props.onRegisterNewObjective}
        onRegisterNewTag={props.onRegisterNewTag}
        allObjectives={props.allObjectives}
        allTags={props.allTags}
        projectSlug={props.projectSlug}
        editorMap={props.editorMap}
        onRemove={() => true}
      />
      <button className="btn btn-primary btn-sm" onClick={onAdd}>
        Add Expression
      </button>
    </div>
  );
};
