import React, { useCallback } from 'react';
import { ControlButtonProps } from './ControlBar';

export const MuteButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  const muted = player?.volume === 0 || player?.muted;
  const toggle = useCallback(() => {
    actions?.mute(!muted);
  }, [actions, muted]);

  return (
    <button className="video-react-control video-react-button" onClick={toggle}>
      <span className="material-icons-outlined">{muted ? 'volume_off' : 'volume_up'}</span>
    </button>
  );
};
