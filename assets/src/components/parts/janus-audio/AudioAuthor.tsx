import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { AudioModel } from './schema';

const AudioAuthor: React.FC<AuthorPartComponentProps<AudioModel>> = (props) => {
  const { id, model } = props;

  const { x, y, z, width, src } = model;
  const styles: CSSProperties = {
    cursor: 'pointer',
    width,
    outline: 'none',
    height: '100%',
    borderRadius: '25px',
    border: '1px solid #ccc!important',
    background: 'whitesmoke',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div data-janus-type={tagName} className="audioPlayer" style={styles}>
      <i className="fas fa-play" style={{ padding: '8px' }}></i>
      <i className="fas fa-ellipsis-v" style={{ float: 'right', padding: '8px' }}></i>
    </div>
  );
};

export const tagName = 'janus-audio';

export default AudioAuthor;
