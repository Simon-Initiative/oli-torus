import React from 'react';

interface Props {
  shouldShow?: boolean;
  disabled?: boolean;
  onClick: () => void;
}
export const ResetButton: React.FC<Props> = ({ disabled = false, shouldShow = true, onClick }) => {
  if (!shouldShow) {
    return null;
  }

  return (
    <button
      aria-label="reset"
      className="btn btn-primary align-self-start mt-3 mb-3"
      disabled={disabled}
      onClick={onClick}
    >
      Reset
    </button>
  );
};
