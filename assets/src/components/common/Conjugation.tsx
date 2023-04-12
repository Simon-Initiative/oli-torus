import * as ContentModel from 'data/content/model/elements/types';
import React, { MouseEventHandler, ReactNode } from 'react';

export const Conjugation: React.FC<{
  conjugation: ContentModel.Conjugation;
  pronunciation: ReactNode;
  table: ReactNode;
  onClick?: MouseEventHandler<HTMLDivElement>;
}> = ({ conjugation, pronunciation, table, onClick }) => {
  return (
    <div className="conjugation" onClick={onClick}>
      <div className="title">{conjugation.title}</div>
      <div className="term">
        {conjugation.verb} {pronunciation}
      </div>
      {table}
    </div>
  );
};
