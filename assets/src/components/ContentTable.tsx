import React from 'react';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
import { classNames } from 'utils/classNames';
import * as ContentTypes from '../data/content/model/elements/types';

export const ContentTable: React.FC<{
  model: ContentTypes.Table;
  children: React.ReactNode;
  pointMarkerContext?: PointMarkerContext;
}> = ({ model, children, pointMarkerContext }) => {
  return (
    <table
      className={classNames(
        'min-w-full',
        model.border === 'hidden' ? 'table-borderless' : 'table-bordered',
        model.rowstyle === 'alternating' && 'table-striped',
      )}
      {...maybePointMarkerAttr(model, pointMarkerContext)}
    >
      {children}
    </table>
  );
};
