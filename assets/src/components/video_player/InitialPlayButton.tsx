import React from 'react';
import { ControlButtonProps } from './ControlBar';

export const InitialPlayButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  if (player?.hasStarted) return null;
  return (
    <button className="big-play-button" onClick={actions?.play}>
      <i className="fa-solid fa-circle-play"></i>
    </button>
  );
};
