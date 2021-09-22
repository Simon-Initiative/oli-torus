import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { AudioModel } from './schema';

const AudioAuthor: React.FC<AuthorPartComponentProps<AudioModel>> = (props) => {
  const { id, model } = props;

  const { x, y, z, width, src } = model;
  const styles: CSSProperties = {
    cursor: 'move',
    width,
    outline: 'none',
    filter: 'sepia(20%) saturate(70%) grayscale(1) contrast(99%) invert(12%)',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return <audio data-janus-type={tagName} style={styles} controls={true} />;
};

export const tagName = 'janus-audio';

export default AudioAuthor;
