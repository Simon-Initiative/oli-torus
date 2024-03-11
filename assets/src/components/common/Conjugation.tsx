import React, { MouseEventHandler, ReactNode } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';

export const Conjugation: React.FC<{
  conjugation: ContentModel.Conjugation;
  pronunciation: ReactNode;
  table: ReactNode;
  pointMarkerContext?: PointMarkerContext;
  onClick?: MouseEventHandler<HTMLDivElement>;
}> = ({ conjugation, pronunciation, table, pointMarkerContext, onClick }) => {
  return (
    <div
      className="conjugation"
      onClick={onClick}
      {...maybePointMarkerAttr(conjugation, pointMarkerContext)}
    >
      <div className="title">{conjugation.title}</div>
      <div className="term">
        {conjugation.verb} {pronunciation}
      </div>
      {table}
    </div>
  );
};
