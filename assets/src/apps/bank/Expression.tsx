import * as React from 'react';
import * as Immutable from 'immutable';
import * as Bank from 'data/content/bank';
import { Objective } from 'data/content/objective';
import { Select } from 'components/common/Selection';
import { Objectives } from 'components/resource/Objectives';
import { Fact } from 'data/content/bank';
import { ActivityEditorMap } from 'data/content/editors';
import { ActivityTypeSelection, ActivityType } from './ActivityTypeSelection';
import { TextInput } from 'components/common/TextInput';

export interface ExpressionProps {
  expression: Bank.Expression;
  onChange: (expression: Bank.Expression) => void;
  onRemove: () => void;
  children?: (item: any, index: number) => React.ReactNode;
  editMode: boolean;
  allowText: boolean;
  allObjectives: Immutable.List<Objective>;
  projectSlug: string;
  onRegisterNewObjective: (objective: Objective) => void;
  editorMap: ActivityEditorMap;
}

const baseFacts = [
  { value: 'objectives', label: 'Objectives' },
  { value: 'type', label: 'Item Type' },
];

type FactOperator = {
  operator: Bank.ExpressionOperator;
  label: string;
  input: 'single' | 'multiple' | 'text';
};

const operatorsByFact: { [id: string]: FactOperator[] } = {
  objectives: [
    { operator: Bank.ExpressionOperator.contains, label: 'Contains', input: 'multiple' },
    {
      operator: Bank.ExpressionOperator.doesNotContain,
      label: 'Does Not Contain',
      input: 'multiple',
    },
    { operator: Bank.ExpressionOperator.doesNotEqual, label: 'Does Not Equal', input: 'multiple' },
    { operator: Bank.ExpressionOperator.equals, label: 'Equals', input: 'multiple' },
  ],
  type: [
    { operator: Bank.ExpressionOperator.contains, label: 'Contains', input: 'multiple' },
    {
      operator: Bank.ExpressionOperator.doesNotContain,
      label: 'Does Not Contain',
      input: 'multiple',
    },
    { operator: Bank.ExpressionOperator.doesNotEqual, label: 'Does Not Equal', input: 'single' },
    { operator: Bank.ExpressionOperator.equals, label: 'Equals', input: 'single' },
  ],
  text: [{ operator: Bank.ExpressionOperator.contains, label: 'Contains Text', input: 'text' }],
};

const textFact = { value: 'text', label: 'Activity Content' };

export const Expression: React.FC<ExpressionProps> = (props: ExpressionProps) => {
  const onChangeFact = (fact: string) => {
    const updated = Object.assign({}, props.expression, { fact });

    // As facts are changed, ensure the operator remains valid for that fact
    if (
      operatorsByFact[fact].filter((fo) => fo.operator === props.expression.operator).length === 0
    ) {
      props.onChange(Object.assign({}, updated, { operator: operatorsByFact[fact][0].operator }));
    } else {
      props.onChange(updated);
    }
  };
  const onChangeOperator = (operator: string) => {
    const updated = Object.assign({}, props.expression, { operator });
    props.onChange(updated);
  };

  const facts = [...baseFacts, ...(props.allowText ? [textFact] : [])].map((f) => {
    return (
      <option key={f.value} value={f.value} selected={props.expression.fact.toString() === f.value}>
        {f.label}
      </option>
    );
  });

  const operators = operatorsByFact[props.expression.operator.toString()].map(
    (factOperator: FactOperator) => {
      return (
        <option
          key={factOperator.operator}
          value={factOperator.operator}
          selected={props.expression.operator === factOperator.operator}
        >
          {factOperator.label}
        </option>
      );
    },
  );

  const buildValueEditor = () => {
    if (props.expression.fact === Fact.objectives) {
      return (
        <Objectives
          onRegisterNewObjective={props.onRegisterNewObjective}
          selected={props.expression.value as number[]}
          onEdit={(value) => {
            props.onChange(Object.assign({}, props.expression, { value }));
          }}
          objectives={props.allObjectives.toArray()}
          editMode={props.editMode}
          projectSlug={props.projectSlug} />
      );
    } else if (props.expression.fact === Fact.type) {

      const activityTypes = Object.keys(props.editorMap)
        .map(k => {
          const e = props.editorMap[k];
          return {
            id: e.id,
            label: e.friendlyName,
          };
        });

      return (
        <ActivityTypeSelection
          selected={props.expression.value as number[]}
          onEdit={(value) => {
            props.onChange(Object.assign({}, props.expression, { value }));
          }}
          multiple={props.expression.operator === Bank.ExpressionOperator.contains
            || props.expression.operator === Bank.ExpressionOperator.doesNotContain}
          activities={activityTypes}
          editMode={props.editMode}
        />
      );
    } else if (props.expression.fact === Fact.text) {
      return (
        <TextInput
          editMode={props.editMode}
          label="Enter search text"
          value={props.expression.value as string}
          type="text"
          onEdit={(value) => {
            props.onChange(Object.assign({}, props.expression, { value }));
          }}
        />
      )
    }
  };

  return (
    <div>
      <Select
        editMode={props.editMode}
        value={props.expression.fact.toString()}
        onChange={(v) => onChangeFact(v)}
      >
        {facts}
      </Select>

      <Select
        editMode={props.editMode}
        value={props.expression.operator.toString()}
        onChange={(v) => onChangeOperator(v)}
      >
        {operators}
      </Select>

      {buildValueEditor()}
    </div>
  );
};
