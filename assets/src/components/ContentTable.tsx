import React from 'react';
import * as ContentTypes from '../data/content/model/elements/types';

export const ContentTable: React.FC<{
  model: ContentTypes.Table;
  children: React.ReactNode;
}> = ({ model, children }) => {
  const cssClasses = [];
  if (model.border === 'hidden') {
    cssClasses.push('table-borderless');
  }

  if (model.rowstyle === 'alternating') {
    cssClasses.push('table-striped');
  }
  return <table className={cssClasses.join(' ')}>{children}</table>;
};
