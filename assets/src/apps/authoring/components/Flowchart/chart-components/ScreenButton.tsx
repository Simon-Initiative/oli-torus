import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';

interface ScreenButtonProps {
  children?: React.ReactNode;
  onClick?: () => void;
  tooltip?: string;
}

export const ScreenButton: React.FC<ScreenButtonProps> = ({ children, onClick, tooltip }) => {
  return (
    <OverlayTrigger
      placement="top"
      delay={{ show: 150, hide: 150 }}
      overlay={
        <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
          {tooltip}
        </Tooltip>
      }
    >
      <button className="screen-button" onClick={onClick}>
        {children}
      </button>
    </OverlayTrigger>
  );
};
