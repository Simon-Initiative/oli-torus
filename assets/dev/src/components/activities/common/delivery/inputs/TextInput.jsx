import React from 'react';
export const TextInput = ({ onChange, value, disabled, placeholder }) => {
    return (<input placeholder={placeholder} type="text" aria-label="answer submission textbox" className="form-control" onChange={onChange} value={value} disabled={typeof disabled === 'boolean' ? disabled : false}/>);
};
//# sourceMappingURL=TextInput.jsx.map