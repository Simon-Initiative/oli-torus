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
      className="px-3 py-2 rounded-sm cursor-pointer text-white self-start mt-3 mb-3 bg-Fill-Buttons-fill-primary hover:bg-Fill-Buttons-fill-primary-hover disabled:text-Text-text-low disabled:bg-Fill-Chip-Gray disabled:cursor-not-allowed"
      disabled={disabled}
      onClick={() => action()}
      onKeyPress={(e) => (e.key === 'Enter' ? action() : null)}
    >
      Reset
    </button>
  );
};
