import React from 'react';
import './Radio.scss';
const Checked = ({ className, disabled }) => (<input className={`oli-radio flex-shrink-0 ${className || ''}`} type="radio" checked disabled={disabled || false} readOnly/>);
const Unchecked = ({ className, disabled }) => (<input className={`oli-radio flex-shrink-0 ${className || ''}`} type="radio" disabled={disabled || false} readOnly/>);
const Correct = () => <Checked className="correct" disabled/>;
const Incorrect = () => <Checked className="incorrect" disabled/>;
export const Radio = {
    Checked,
    Unchecked,
    Correct,
    Incorrect,
};
//# sourceMappingURL=Radio.jsx.map