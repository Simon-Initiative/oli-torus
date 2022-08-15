import React from 'react';
import { MathLive } from 'components/common/MathLive';

interface InputProps {
  value: string;
  disabled?: boolean;
  onChange: (value: string) => void;
}

export const MathInput: React.FC<InputProps> = ({ value, disabled, onChange }) => {
  return (
    <MathLive
      value={value}
      options={{
        readOnly: disabled,
      }}
      onChange={onChange}
    />
  );
};
