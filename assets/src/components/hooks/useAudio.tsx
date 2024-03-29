import React, { useState } from 'react';
import { useCallback, useRef } from 'react';

/* Hook to add a simple audio player to a component.

  Usage:
    const { audioPlayer, playAudio } = useAudio(pronunciation.src);

  playAudio - callback to actually play the audio
  audioPlayer - an <audio> component that you must make sure gets rendered into the tree
  isPlaying - boolean to let you know if the audio is playing

 */

export const useAudio = (src?: string) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);

  const playAudio = useCallback((event?: any) => {
    event?.preventDefault && event?.preventDefault(); // Fixes https://eliterate.atlassian.net/browse/MER-1503

    const audio = audioRef.current;
    if (audio) {
      if (audio.paused) {
        audio.currentTime = 0;
        audio.play().then(() => setIsPlaying(true));
        audio.onabort = () => setIsPlaying(false);
        audio.onerror = () => setIsPlaying(false);
        audio.onended = () => setIsPlaying(false);
      } else {
        setIsPlaying(false);
        audio.pause();
      }
    }
  }, []);

  const audioPlayer = src ? <audio ref={audioRef} src={src} preload="auto"></audio> : null;

  return { audioPlayer, playAudio, isPlaying };
};
