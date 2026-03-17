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
      className="px-3 py-2 rounded-sm cursor-pointer text-white self-start mt-3 mb-3 bg-Fill-Buttons-fill-primary hover:bg-Fill-Buttons-fill-primary-hover disabled:text-Text-text-low disabled:bg-Fill-Chip-Gray disabled:cursor-not-allowed"
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  );
};
