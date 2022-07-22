import React, { useCallback } from 'react';
import { ControlButtonProps } from './ControlBar';

export const FullScreenButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  const isFullscreen = player?.isFullscreen;
  const toggle = useCallback(() => {
    player && actions?.toggleFullscreen(player);
  }, [actions, player]);

  return (
    <button className="video-react-control video-react-button" onClick={toggle}>
      <span className="material-icons-outlined">
        {isFullscreen ? 'close_fullscreen' : 'fullscreen'}
      </span>
    </button>
  );
};
