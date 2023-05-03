import React from 'react';
import { classNames } from 'utils/classNames';
import * as ContentTypes from '../data/content/model/elements/types';

export const ContentTable: React.FC<{
  model: ContentTypes.Table;
  children: React.ReactNode;
}> = ({ model, children }) => {
  return (
    <table
      className={classNames(
        'min-w-full',
        model.border === 'hidden' ? 'table-borderless' : 'table-bordered',
        model.rowstyle === 'alternating' && 'table-striped',
      )}
    >
      {children}
    </table>
  );
};
