import React from 'react';

interface Props {
  shouldShow?: boolean;
  disabled?: boolean;
  onClick: () => void;
  label?: string;
}
export const SubmitButton: React.FC<Props> = ({
  shouldShow = true,
  disabled = false,
  onClick,
  label = 'Submit',
}) => {
  if (!shouldShow) {
    return null;
  }

  return (
    <button
      aria-label="submit"
      className="btn btn-primary self-start mt-3 mb-3"
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  );
};
