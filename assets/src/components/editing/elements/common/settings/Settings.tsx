import { Tooltip } from 'components/common/Tooltip';
import React from 'react';
import './Settings.scss';

// Reusable components for settings UIs

export const onEnterApply = (e: React.KeyboardEvent, onApply: () => void) => {
  if (e.key === 'Enter') {
    onApply();
  }
};

export const Action = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <Tooltip title={tooltip}>
      <span id={id} style={{ cursor: 'pointer ' }}>
        <i onClick={onClick} className={icon + ' mr-2'}></i>
      </span>
    </Tooltip>
  );
};
