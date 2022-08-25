import React, { useCallback, useRef } from 'react';
import * as ContentModel from '../../data/content/model/elements/types';
import { Next } from '../../data/content/writers/writer';

export const DefinitionPronunciation: React.FC<{
  pronunciation: ContentModel.DefinitionPronunciation;
  next: Next;
}> = ({ next, pronunciation }) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const playAudio = useCallback(() => {
    if (audioRef.current) {
      if (audioRef.current.paused) {
        audioRef.current.currentTime = 0;
        audioRef.current.play();
      } else {
        audioRef.current.pause();
      }
    }
  }, []);

  if (!pronunciation.src) {
    return <span className="pronunciation">{next()} </span>;
  }

  return (
    <>
      <span className="material-icons-outlined play-button" onClick={playAudio}>
        play_circle
      </span>
      <span className="pronunciation-player" onClick={playAudio}>
        <audio ref={audioRef} src={pronunciation.src}></audio>
        {next()}{' '}
      </span>
    </>
  );
};
