import React from 'react';

interface ScreenButtonProps {
  children?: React.ReactNode;
  onClick?: () => void;
}

export const ScreenButton: React.FC<ScreenButtonProps> = ({ children, onClick }) => {
  return (
    <button className="screen-button" onClick={onClick}>
      {children}
    </button>
  );
};
