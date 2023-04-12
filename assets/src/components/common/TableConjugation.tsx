// A special <td> used in the table inside conjugations
import * as ContentModel from '../../data/content/model/elements/types';
import { cellAttributes } from '../editing/elements/table/table-util';
import { useAudio } from '../hooks/useAudio';
import React from 'react';
import { ReactNode } from 'react';

interface Props {
  children: ReactNode;
  attrs: ContentModel.TableConjugation;
}

export const TableConjugation: React.FC<Props> = ({ attrs, children }) => {
  const { audioPlayer, playAudio } = useAudio(attrs.audioSrc);
  const audioClass = attrs.audioSrc ? 'clickable' : '';
  return (
    <td {...cellAttributes(attrs, `conjugation-cell ${audioClass}`)} onClick={playAudio}>
      {attrs.pronouns && <i>{attrs.pronouns} </i>}
      {children}
      {audioPlayer}
    </td>
  );
};
