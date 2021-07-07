import React from 'react';
interface Props {
  shouldShow?: boolean;
  disabled?: boolean;
  onClick: () => void;
}
export const SubmitButton: React.FC<Props> = ({ shouldShow = true, disabled = false, onClick }) => {
  if (!shouldShow) {
    return null;
  }

  return (
    <button
      aria-label="submit"
      className="btn btn-primary align-self-start mt-3 mb-3"
      disabled={disabled}
      onClick={onClick}
    >
      Submit
    </button>
  );
};
