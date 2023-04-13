import React, { useCallback } from 'react';
import { ControlButtonProps } from './ControlBar';

export const FullScreenButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  const isFullscreen = player?.isFullscreen;
  const toggle = useCallback(() => {
    player && actions?.toggleFullscreen(player);
  }, [actions, player]);

  return (
    <button className="video-react-control video-react-button" onClick={toggle}>
      {isFullscreen ? (
        <i className="fa-solid fa-down-left-and-up-right-to-center"></i>
      ) : (
        <i className="fa-solid fa-up-right-and-down-left-from-center"></i>
      )}
    </button>
  );
};
