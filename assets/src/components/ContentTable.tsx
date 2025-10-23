import React from 'react';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
import { classNames } from 'utils/classNames';
import * as ContentTypes from '../data/content/model/elements/types';

export const ContentTable: React.FC<{
  model: ContentTypes.Table;
  children: React.ReactNode;
  pointMarkerContext?: PointMarkerContext;
  isEditing?: boolean;
}> = ({ model, children, pointMarkerContext, isEditing = false }) => {
  return (
    <table
      className={classNames(
        'min-w-full',
        model.border === 'hidden' ? 'table-borderless' : 'table-bordered',
        model.rowstyle === 'alternating' && 'table-striped',
        isEditing && '!overflow-visible',
      )}
      {...maybePointMarkerAttr(model, pointMarkerContext)}
    >
      {children}
    </table>
  );
};
