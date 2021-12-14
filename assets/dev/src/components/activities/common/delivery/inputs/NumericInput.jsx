import React from 'react';
export const NumericInput = (props) => {
    return (<input placeholder={props.placeholder} type="number" aria-label="answer submission textbox" className="form-control" onChange={props.onChange} value={props.value} disabled={typeof props.disabled === 'boolean' ? props.disabled : false}/>);
};
//# sourceMappingURL=NumericInput.jsx.map