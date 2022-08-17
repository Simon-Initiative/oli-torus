import React, { useEffect } from 'react';
interface CustomCheckboxProps {
  label: string;
  id: string;
  value: boolean;
  onChange: (value: boolean) => void;
}
const CustomCheckbox: React.FC<CustomCheckboxProps> = (props) => {
  const [checked, setChecked] = React.useState(props.value);

  useEffect(() => {
    setChecked(props.value);
  }, [props.value]);

  return (
    <div className="d-flex justify-content-between">
      <span className="form-label">{props.label}</span>
      <input
        type="checkbox"
        className="my-auto"
        id={props.id}
        checked={!!checked}
        onClick={() => {
          setChecked(!checked);
          props.onChange(!checked);
        }}
        onChange={(e) => {
          /* console.log('CustomCheckbox onChange', { el: e.target.checked, checked }); */
        }}
      />
    </div>
  );
};

export default CustomCheckbox;
