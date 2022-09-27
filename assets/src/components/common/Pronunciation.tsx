import React from 'react';
import * as ContentModel from '../../data/content/model/elements/types';
import { Next } from '../../data/content/writers/writer';
import { useAudio } from '../hooks/useAudio';

export const Pronunciation: React.FC<{
  pronunciation: ContentModel.Pronunciation;
  next: Next;
}> = ({ next, pronunciation }) => {
  const { audioPlayer, playAudio, isPlaying } = useAudio(pronunciation.src);

  if (!pronunciation.src) {
    return <span className="pronunciation">{next()} </span>;
  }

  return (
    <span className="pronunciation">
      <span className="material-icons-outlined play-button" onClick={playAudio}>
        {isPlaying ? 'stop_circle' : 'play_circle'}
      </span>
      <span className="pronunciation-player" onClick={playAudio}>
        {next()} {audioPlayer}
      </span>
    </span>
  );
};
