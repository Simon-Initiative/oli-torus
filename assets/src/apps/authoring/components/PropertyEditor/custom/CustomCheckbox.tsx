import React from 'react';
const CustomCheckbox = (props: any) => {
  return (
    <div className="d-flex justify-content-between" >
      <span className="form-label">{props.label}</span>
      <input
        type="checkbox"
        className="my-auto"
        id={props.id}
        checked={props.value}
        onClick={() => props.onChange(!props.value)}
      />
    </div>
  );
};

export default CustomCheckbox;
