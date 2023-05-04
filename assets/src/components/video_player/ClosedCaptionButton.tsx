import React, { useCallback } from 'react';

export const ClosedCaptionButton: React.FC<any> = (props) => {
  const { actions, player } = props;
  const { textTracks } = player;
  const [menuOpen, setMenuOpen] = React.useState(false);

  const toggleMenu = useCallback(() => {
    setMenuOpen((menuOpen) => !menuOpen);
  }, []);

  const activateTrack = useCallback(
    (track: any) => (event: React.MouseEvent) => {
      setMenuOpen(false);
      event.stopPropagation();
      Array.from(textTracks).forEach((t: any) => {
        t.mode = t === track ? 'showing' : 'disabled';
      });
      if (track) {
        actions.activateTextTrack(track);
      }
    },
    [actions, textTracks],
  );

  if (!textTracks || textTracks.length === 0) return null;

  return (
    <button
      onClick={toggleMenu}
      className="video-react-control video-react-button video-captions-button"
    >
      {menuOpen && <TrackMenu tracks={textTracks} activateTrack={activateTrack} />}
      <i className="fa-solid fa-closed-captioning"></i>
    </button>
  );
};

const TrackMenu: React.FC<{
  tracks: any[];
  activateTrack: (track: any) => (event: React.MouseEvent) => void;
}> = ({ tracks, activateTrack }) => {
  return (
    <ul className="captions-menu">
      <li className="captions-menu-item" onClick={activateTrack(null)}>
        No Captions
      </li>
      {Array.from(tracks)
        .filter((t) => t.kind == 'captions' || t.kind == 'subtitles')
        .map((track, idx) => (
          <li className="captions-menu-item" onClick={activateTrack(track)} key={idx}>
            {track.label}
          </li>
        ))}
    </ul>
  );
};
