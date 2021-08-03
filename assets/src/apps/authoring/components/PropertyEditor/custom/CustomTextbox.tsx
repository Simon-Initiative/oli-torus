import React from 'react';
import { useEffect, useState } from 'react';

interface CustomTextboxProps {
  label: string;
  id: string;
  value: string;
}
const CustomTextbox: React.FC<CustomTextboxProps> = (props: any) => {
  const [value, setValue] = useState<string>(props.value);
  useEffect(() => {
    setValue(props.value);
  }, [props]);
  return (
    <div className="mb-0 form-group">
      <span className="form-label">{props.label}</span>
      <input
        className="form-control"
        type="text"
        id={props.id}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onBlur={(e) => props.onChange(e.target.value)}
      />
    </div>
  );
};

export default CustomTextbox;
