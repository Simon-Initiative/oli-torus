import * as React from 'react';
import guid from 'utils/guid';
export const Select = (props) => {
    const id = guid();
    const select = (<select disabled={!props.editMode} value={props.value} onChange={(e) => props.onChange(e.target.value)} className={`form-control-sm custom-select mb-2 mr-sm-2 mb-sm-0 ${props.className}`} id={id}>
      {props.children}
    </select>);
    if (props.label !== undefined && props.label !== '') {
        return (<label className="mr-sm-2" htmlFor={id}>
        {props.label}&nbsp;&nbsp;
        {select}
      </label>);
    }
    return select;
};
//# sourceMappingURL=Selection.jsx.map