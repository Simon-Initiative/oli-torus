import React from 'react';
export const TextareaInput = (props) => {
    return (<textarea aria-label="answer submission textbox" rows={typeof props.rows === 'number' ? props.rows : 5} cols={typeof props.rows === 'number' ? props.cols : 80} className="form-control" onChange={props.onChange} value={props.value} disabled={typeof props.disabled === 'boolean' ? props.disabled : false}></textarea>);
};
//# sourceMappingURL=TextareaInput.jsx.map