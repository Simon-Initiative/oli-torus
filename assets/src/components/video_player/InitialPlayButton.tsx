import React from 'react';
import { ControlButtonProps } from './ControlBar';

export const InitialPlayButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  if (player?.hasStarted) return null;
  return (
    <button className="big-play-button" onClick={actions?.play}>
      <span className="material-icons-outlined play-icon">play_circle_filled</span>
    </button>
  );
};
