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
      className="btn text-Text-text-white self-start mt-3 mb-3 bg-Fill-Buttons-fill-primary hover:text-Specially-Tokens-Text-text-button-primary-hover hover:bg-Fill-Buttons-fill-primary-hover"
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  );
};
