import React from 'react';
import * as Immutable from 'immutable';
import { TextInput } from 'components/common/TextInput';
import { LogicBuilder } from 'components/logic/LogicBuilder';
import * as Bank from 'data/content/bank';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { ActivityBankSelection, ActivityBankSelection as Selection } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import './ActivityBankSelectionEditor.scss';
import { Description, Icon, OutlineItem, OutlineItemProps } from './OutlineItem';

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

  const onEditPoints = (points: string) => {
    let pointsPerActivity;

    try {
      pointsPerActivity = parseInt(points, 10);
    } catch (e) {
      pointsPerActivity = 1;
    }

    if (isNaN(pointsPerActivity) || pointsPerActivity <= 0) {
      pointsPerActivity = 1;
    }

    onEdit(Object.assign({}, contentItem, { pointsPerActivity }));
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

  const pointsValue =
    contentItem.pointsPerActivity === undefined ? 1 : contentItem.pointsPerActivity;

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
      <div className="d-flex justify-items-start mb-4">
        <div className="mr-3">Points per question:</div>
        <div className="count-input">
          <TextInput
            onEdit={onEditPoints}
            type="number"
            editMode={editMode}
            value={pointsValue.toString()}
            label="Points per question"
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

interface SelectionOutlineItemProps extends OutlineItemProps {
  contentItem: ActivityBankSelection;
}
export const SelectionOutlineItem = (props: SelectionOutlineItemProps) => {
  const { contentItem } = props;
  return (
    <OutlineItem {...props}>
      <Icon iconName="fas fa-cogs" />
      <Description title="Activity Bank Selection">
        {getActivitySelectionDescription(contentItem)}
      </Description>
    </OutlineItem>
  );
};

const getActivitySelectionDescription = (selection: ActivityBankSelection) => {
  return `${selection.count} selection${selection.count > 1 ? 's' : ''}`;
};
