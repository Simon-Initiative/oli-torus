import React, { useCallback } from 'react';
import { ControlButtonProps } from './ControlBar';

export const PlayButton: React.FC<ControlButtonProps> = ({ actions, player }) => {
  const toggle = useCallback(() => {
    player?.paused ? actions?.play() : actions?.pause();
  }, [actions, player]);

  const playOrPausedStyle = player?.paused ? 'fa-solid fa-play' : 'fa-solid fa-pause';

  return (
    // The 'key' attribute is necessary here to force react to replace the entire buton on
    // a "play/pause" state change, so that we can replace the font-awesome icon correctly.
    <button
      key={player?.paused + ''}
      className="video-react-control video-react-button"
      onClick={toggle}
    >
      <i className={playOrPausedStyle}></i>
    </button>
  );
};
