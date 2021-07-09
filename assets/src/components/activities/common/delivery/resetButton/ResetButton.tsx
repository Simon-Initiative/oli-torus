import React from 'react';

interface Props {
  shouldShow?: boolean;
  disabled?: boolean;
  action: () => void;
}
export const ResetButton: React.FC<Props> = ({ disabled = false, shouldShow = true, action }) => {
  if (!shouldShow) {
    return null;
  }

  return (
    <button
      aria-label="reset"
      className="btn btn-primary align-self-start mt-3 mb-3"
      disabled={disabled}
      onClick={() => action()}
      onKeyPress={(e) => (e.key === 'Enter' ? action() : null)}
    >
      Reset
    </button>
  );
};
