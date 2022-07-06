import React from 'react';

interface Props {
  value: string | number;
  disabled?: boolean;
}
export const VlabInput: React.FC<Props> = (props) => {
  return (
    <input
      type="hidden"
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
    />
  );
};
