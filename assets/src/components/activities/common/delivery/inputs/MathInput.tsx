import React from 'react';
import { MathLive } from 'components/common/MathLive';

interface InputProps {
  value: string;
  disabled?: boolean;
  inline?: boolean;
  onChange: (value: string) => void;
}

export const MathInput: React.FC<InputProps> = ({ value, inline, disabled, onChange }) => {
  return (
    <MathLive
      inline={inline}
      value={value}
      options={{
        readOnly: disabled,
      }}
      onChange={onChange}
    />
  );
};
