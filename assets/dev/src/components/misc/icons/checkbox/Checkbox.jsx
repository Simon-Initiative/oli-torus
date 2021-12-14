import React from 'react';
import './Checkbox.scss';
const Checked = ({ className, disabled }) => (<input className={`oli-checkbox flex-shrink-0 ${className || ''}`} type="checkbox" checked disabled={disabled || false} readOnly/>);
const Unchecked = ({ className, disabled }) => (<input className={`oli-checkbox flex-shrink-0 ${className || ''}`} type="checkbox" disabled={disabled || false} readOnly/>);
const Correct = () => <Checked className="correct" disabled/>;
const Incorrect = () => <Checked className="incorrect" disabled/>;
export const Checkbox = {
    Checked,
    Unchecked,
    Correct,
    Incorrect,
};
//# sourceMappingURL=Checkbox.jsx.map