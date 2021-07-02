import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { Response } from 'components/activities/types';
import { useState } from 'react';
import React from 'react';
import {
  isOperator,
  makeNumericRule,
  NumericOperator,
  parseNumericInputFromRule,
  parseOperatorFromRule,
} from 'components/activities/common/responses/authoring/rules';
import { numericOptions } from 'components/activities/short_answer/sections/numericInput/numericUtils';

interface InputProps {
  response: Response;
  onEditResponseRule: (rule: string) => void;
}
export const NumericInput: React.FC<InputProps> = ({ response, onEditResponseRule }) => {
  const { editMode } = useAuthoringElementContext();

  const [value, setValue] = useState(parseNumericInputFromRule(response.rule));
  const [operator, setOperator] = useState(parseOperatorFromRule(response.rule) || 'eq');

  const setNumericRule = (operator: NumericOperator, input: string | [string, string]) => {
    console.log('operator', operator, 'input', input);

    console.log('new rule', makeNumericRule(operator, input));
    onEditResponseRule(makeNumericRule(operator, input));
  };
  return (
    <div className="d-flex">
      <select
        disabled={!editMode}
        className="form-control"
        value={operator}
        onChange={(e) => {
          if (!isOperator(e.target.value)) {
            return;
          }
          setOperator(e.target.value);
          setNumericRule(e.target.value, value);
        }}
        name="question-type"
        id="question-type"
      >
        {numericOptions.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
      <input
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue =
            operator === 'btw' || operator === 'nbtw'
              ? ([e.target.value, value[1]] as [string, string])
              : e.target.value;
          setValue(newValue);
          console.log('new rule', makeNumericRule(operator, newValue));
          onEditResponseRule(makeNumericRule(operator, newValue));
        }}
        value={value}
      />
      {(operator === 'btw' || operator === 'nbtw') && (
        <input
          disabled={!editMode}
          type="number"
          className="form-control"
          onChange={(e) => {
            const newValue = [value[0], e.target.value] as [string, string];
            setValue(newValue);
            console.log('new rule', makeNumericRule(operator, newValue));
            onEditResponseRule(makeNumericRule(operator, newValue));
          }}
          value={value}
        />
      )}
    </div>
  );
};
