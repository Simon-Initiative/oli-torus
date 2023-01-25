import React, { useCallback } from 'react';
import { ControlButtonProps } from './ControlBar';

export const PlayButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  const toggle = useCallback(() => {
    player?.paused ? actions?.play() : actions?.pause();
  }, [actions, player]);

  return (
    <button className="video-react-control video-react-button" onClick={toggle}>
      {player?.paused ? (
        <i className="fa-solid fa-pause"></i>
      ) : (
        <i className="fa-solid fa-play"></i>
      )}
    </button>
  );
};
