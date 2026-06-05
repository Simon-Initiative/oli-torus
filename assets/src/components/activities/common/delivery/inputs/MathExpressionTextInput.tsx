import React, { createRef, useEffect, useState } from 'react';
import { MathExpressionSyntaxKind, validateMathExpressionSyntax } from 'gleam/torusExpression';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { classNames } from 'utils/classNames';

interface Props {
  value: string;
  validationKind: MathExpressionSyntaxKind;
  disabled?: boolean;
  placeholder?: string;
  size?: MultiInputSize;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}

export const MathExpressionTextInput: React.FC<Props> = ({
  value,
  validationKind,
  disabled,
  placeholder,
  size,
  onChange,
  onBlur,
  onKeyUp,
}) => {
  const inputRef = createRef<HTMLInputElement>();
  const [isValid, setIsValid] = useState(false);

  useEffect(() => {
    const trimmed = value.trim();
    if (trimmed === '') {
      setIsValid(false);
      return;
    }

    const result = validateMathExpressionSyntax(trimmed, validationKind);
    setIsValid(result.status === 'valid');
  }, [validationKind, value]);

  return (
    <input
      ref={inputRef}
      placeholder={placeholder}
      type="text"
      aria-label="answer submission textbox"
      aria-invalid={!isValid}
      className={classNames(
        'rounded-md border-2 disabled:bg-gray-100 disabled:text-gray-600',
        isValid ? 'input-success' : 'input-error',
        'focus:outline-none',
        size && `input-size-${size}`,
      )}
      onChange={(e) => onChange(e.target.value)}
      onBlur={onBlur}
      onKeyUp={onKeyUp}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
