import React from 'react';
export const InputTypeDropdown = ({ onChange, editMode, selected, options, }) => {
    const handleChange = (e) => {
        if (!options.find(({ value }) => value === e.target.value)) {
            return;
        }
        onChange(e.target.value);
    };
    return (<select style={{ width: 150 }} disabled={!editMode} className="form-control ml-1" value={selected} onChange={handleChange} name="question-type" id="question-type">
      {options.map((option) => (<option key={option.value} value={option.value}>
          {option.displayValue}
        </option>))}
    </select>);
};
//# sourceMappingURL=InputTypeDropdown.jsx.map