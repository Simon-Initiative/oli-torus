import React, { CSSProperties } from 'react';
import { useGifPlayer } from './hooks/useGifPlayer';

interface GifPlayerProps {
  src: string;
  alt: string;
  decorative?: boolean;
  className?: string;
  style?: CSSProperties;
  onClick?: () => void;
  dataJanusType?: string;
}

const playPauseButtonStyle: CSSProperties = {
  position: 'absolute',
  bottom: 8,
  right: 8,
  width: 32,
  height: 32,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  borderRadius: '50%',
  border: 'none',
  background: 'rgba(0,0,0,0.55)',
  color: '#fff',
  cursor: 'pointer',
  padding: 0,
  zIndex: 1,
};

const skeletonOverlayStyle: CSSProperties = {
  position: 'absolute',
  inset: 0,
  borderRadius: 4,
  background:
    'linear-gradient(90deg, rgba(229,231,235,0.9) 0%, rgba(243,244,246,0.95) 50%, rgba(229,231,235,0.9) 100%)',
  backgroundSize: '200% 100%',
  animation: 'janus-image-gif-skeleton 1.2s ease-in-out infinite',
  pointerEvents: 'none',
};

const GifPlayer: React.FC<GifPlayerProps> = ({
  src,
  alt,
  decorative = false,
  className,
  style,
  onClick,
  dataJanusType,
}) => {
  const { canvasRef, isPlaying, toggle, status } = useGifPlayer(src);

  if (status === 'error') {
    return (
      <img
        data-janus-type={dataJanusType}
        data-testid="janus-image-gif-fallback"
        src={src}
        alt={decorative ? '' : alt}
        aria-hidden={decorative || undefined}
        className={className}
        style={style}
        draggable={false}
        onClick={onClick}
      />
    );
  }

  const labelSuffix = alt ? `: ${alt}` : '';

  return (
    <span
      className={className}
      style={{
        position: 'relative',
        display: 'block',
        maxWidth: '100%',
        lineHeight: 0,
        ...style,
      }}
      onClick={onClick}
      data-janus-type={dataJanusType}
      data-testid="janus-image-gif"
    >
      {status === 'loading' && <span aria-hidden="true" style={skeletonOverlayStyle} />}
      <style type="text/css">{`
        @keyframes janus-image-gif-skeleton {
          0% { background-position: 200% 0; }
          100% { background-position: -200% 0; }
        }
      `}</style>
      <canvas
        ref={canvasRef}
        className="janus-image-gif-canvas"
        data-testid="janus-image-gif-canvas"
        role={decorative ? 'presentation' : 'img'}
        aria-label={decorative ? undefined : alt}
        aria-hidden={decorative || undefined}
        style={{ width: '100%', height: 'auto', display: 'block' }}
      />
      {status === 'ready' && (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            toggle();
          }}
          aria-pressed={isPlaying}
          aria-label={isPlaying ? `Pause animation${labelSuffix}` : `Play animation${labelSuffix}`}
          style={playPauseButtonStyle}
        >
          {isPlaying ? (
            <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden="true" focusable="false">
              <rect x="2" y="1" width="3.5" height="12" fill="currentColor" />
              <rect x="8.5" y="1" width="3.5" height="12" fill="currentColor" />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden="true" focusable="false">
              <polygon points="2,1 13,7 2,13" fill="currentColor" />
            </svg>
          )}
        </button>
      )}
    </span>
  );
};

export default GifPlayer;
