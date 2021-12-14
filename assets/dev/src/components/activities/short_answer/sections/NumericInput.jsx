import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import React from 'react';
import { isOperator } from 'data/activities/model/rules';
const SimpleNumericInput = ({ state, setState }) => {
    const { editMode } = useAuthoringElementContext();
    if (isRangeOperator(state.operator) || typeof state.input !== 'string') {
        return null;
    }
    return (<input disabled={!editMode} type="number" className="form-control" onChange={(e) => {
            setState({ input: e.target.value, operator: state.operator });
        }} value={state.input}/>);
};
const RangeNumericInput = ({ state, setState }) => {
    const { editMode } = useAuthoringElementContext();
    if (!isRangeOperator(state.operator) || typeof state.input === 'string') {
        return null;
    }
    return (<div className="d-flex flex-column d-md-flex flex-md-row align-items-center">
      <input disabled={!editMode} type="number" className="form-control" onChange={(e) => {
            const newValue = [e.target.value, state.input[1]];
            setState({ input: newValue, operator: state.operator });
        }} value={state.input[0]}/>
      <div className="mx-1">and</div>
      <input placeholder="Correct answer" disabled={!editMode} type="number" className="form-control" onChange={(e) => {
            const newValue = [state.input[0], e.target.value];
            setState({ input: newValue, operator: state.operator });
        }} value={state.input[1]}/>
    </div>);
};
const isRangeOperator = (op) => op === 'btw' || op === 'nbtw';
export const NumericInput = ({ setState, state }) => {
    const { editMode } = useAuthoringElementContext();
    const shared = {
        state,
        setState,
    };
    return (<div className="d-flex flex-column flex-md-row mb-2">
      <select disabled={!editMode} className="form-control mr-1" value={state.operator} onChange={(e) => {
            const nextOp = e.target.value;
            if (!isOperator(nextOp)) {
                return;
            }
            let nextValue;
            if (isRangeOperator(nextOp) && !isRangeOperator(state.operator)) {
                nextValue = [state.input, state.input];
            }
            else if (isRangeOperator(state.operator) && !isRangeOperator(nextOp)) {
                nextValue = state.input[0];
            }
            else {
                nextValue = state.input;
            }
            setState({ operator: nextOp, input: nextValue });
        }} name="question-type">
        {numericOptions.map((option) => (<option key={option.value} value={option.value}>
            {option.displayValue}
          </option>))}
      </select>
      <RangeNumericInput {...shared}/>
      <SimpleNumericInput {...shared}/>
    </div>);
};
export const numericOptions = [
    { value: 'gt', displayValue: 'Greater than' },
    { value: 'gte', displayValue: 'Greater than or equal to' },
    { value: 'lt', displayValue: 'Less than' },
    { value: 'lte', displayValue: 'Less than or equal to' },
    { value: 'eq', displayValue: 'Equal to' },
    { value: 'neq', displayValue: 'Not equal to' },
    { value: 'btw', displayValue: 'Between' },
    { value: 'nbtw', displayValue: 'Not between' },
];
//# sourceMappingURL=NumericInput.jsx.map