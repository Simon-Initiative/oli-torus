import * as React from 'react';
import * as Bank from 'data/content/bank';
import { Select } from 'components/common/Selection';
import { ObjectivesSelection } from 'components/resource/objectives/ObjectivesSelection';
import { Fact } from 'data/content/bank';
import { Tags } from 'components/resource/Tags';
import { ActivityTypeSelection } from './ActivityTypeSelection';
import { TextInput } from 'components/common/TextInput';
import { LogicProps } from '../../components/logic/common';
import { CloseButton } from '../../components/misc/CloseButton';

export interface ExpressionProps extends LogicProps {
  expression: Bank.Expression;
  onChange: (expression: Bank.Expression) => void;

  // Controls the mode to allow usage wihin a "fixed" UI
  // context where the user cannot change the fact or remove the expression
  fixedFact?: boolean;
}

const baseFacts = [
  { value: 'objectives', label: 'Objectives' },
  { value: 'type', label: 'Item Type' },
  { value: 'tags', label: 'Tags' },
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
  tags: [
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
  ],
  text: [{ operator: Bank.ExpressionOperator.contains, label: 'Contains Text', input: 'text' }],
};

const textFact = { value: 'text', label: 'Activity Content' };

export const Expression: React.FC<ExpressionProps> = (props: ExpressionProps) => {
  const onChangeFact = (fact: string) => {
    // change fact and reset the value list
    const updated = Object.assign({}, props.expression, { fact, value: [] });

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

  const operators = operatorsByFact[props.expression.fact.toString()].map(
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
        <ObjectivesSelection
          onRegisterNewObjective={props.onRegisterNewObjective}
          selected={props.expression.value as number[]}
          onEdit={(value) => {
            props.onChange(Object.assign({}, props.expression, { value }));
          }}
          objectives={props.allObjectives.toArray()}
          editMode={props.editMode}
          projectSlug={props.projectSlug}
        />
      );
    } else if (props.expression.fact === Fact.type) {
      const activityTypes = Object.keys(props.editorMap).map((k) => {
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
          multiple={
            props.expression.operator === Bank.ExpressionOperator.contains ||
            props.expression.operator === Bank.ExpressionOperator.doesNotContain
          }
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
      );
    } else if (props.expression.fact === Fact.tags) {
      return (
        <Tags
          onRegisterNewTag={props.onRegisterNewTag}
          selected={props.expression.value as number[]}
          onEdit={(value) => {
            props.onChange(Object.assign({}, props.expression, { value }));
          }}
          tags={props.allTags.toArray()}
          editMode={props.editMode}
          projectSlug={props.projectSlug}
        />
      );
    }
  };

  const removeButton = props.fixedFact ? null : (
    <div className="remove">
      <CloseButton editMode={props.editMode} onClick={() => props.onRemove()} />
    </div>
  );

  return (
    <div className="expression">
      <div className="fact">
        <Select
          editMode={props.editMode && !props.fixedFact}
          value={props.expression.fact.toString()}
          onChange={(v) => onChangeFact(v)}
        >
          {facts}
        </Select>
      </div>
      <div className="operator">
        <Select
          editMode={props.editMode}
          value={props.expression.operator.toString()}
          onChange={(v) => onChangeOperator(v)}
        >
          {operators}
        </Select>
      </div>
      <div className="value">{buildValueEditor()}</div>
      {removeButton}
    </div>
  );
};
