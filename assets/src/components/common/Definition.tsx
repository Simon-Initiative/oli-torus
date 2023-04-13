import React, { MouseEventHandler, ReactNode } from 'react';
import * as ContentModel from 'data/content/model/elements/types';

export const Definition: React.FC<{
  definition: ContentModel.Definition;
  meanings: ReactNode;
  pronunciation: ReactNode;
  translations: ReactNode;
  onClick?: MouseEventHandler<HTMLDivElement>;
}> = ({ definition, meanings, pronunciation, translations, onClick }) => {
  const meaningsClass = definition.meanings.length === 1 ? 'meanings-single' : 'meanings';
  return (
    <div className="definition" onClick={onClick}>
      <div className="term">{definition.term}</div>
      <i>(definition) </i>
      <span className="definition-header">
        {definition.pronunciation && 'Pronunciation: '}
        {pronunciation}
        <span className="definition-pronunciation">{translations}</span>
      </span>
      <ol className={meaningsClass}>{meanings}</ol>
    </div>
  );
};
