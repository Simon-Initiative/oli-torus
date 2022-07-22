interface VideoPlayer {
  hasStarted: boolean;
  paused: boolean;
  volume: number;
  muted: boolean;
  isFullscreen: boolean;
}

export interface ControlButtonProps {
  order?: number;
  actions?: {
    play: () => void;
    pause: () => void;
    mute: (muted: boolean) => void;
    toggleFullscreen: (player: VideoPlayer) => void;
  };
  player?: VideoPlayer;
}
