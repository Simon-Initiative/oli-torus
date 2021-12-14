import React from 'react';
export const DropdownInput = (props) => {
    const options = [
        {
            value: '',
            displayValue: '',
        },
        ...props.options,
    ];
    return (<select onChange={props.onChange} disabled={typeof props.disabled === 'boolean' ? props.disabled : false} className="custom-select" style={{ flexBasis: '160px', width: '160px' }}>
      {options.map((option, i) => (<option selected={option.value === props.selected} key={i} value={option.value}>
          {option.displayValue}
        </option>))}
    </select>);
};
//# sourceMappingURL=DropdownInput.jsx.map