import React from 'react';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { MathLive } from 'components/common/MathLive';
import { classNames } from 'utils/classNames';

interface InputProps {
  value: string;
  disabled?: boolean;
  inline?: boolean;
  size?: MultiInputSize;
  onChange: (value: string) => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  onBlur?: () => void;
}

export const MathInput: React.FC<InputProps> = ({
  value,
  inline,
  disabled,
  size,
  onChange,
  onKeyUp,
  onBlur,
}) => {
  return (
    <MathLive
      className={classNames('math-input', size && `input-size-${size}`)}
      inline={inline}
      value={value}
      options={{
        readOnly: disabled,
      }}
      onChange={onChange}
      onKeyUp={onKeyUp}
      onBlur={onBlur}
    />
  );
};
