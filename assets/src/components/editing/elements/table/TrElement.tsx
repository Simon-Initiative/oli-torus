import { EditorProps } from 'components/editing/elements/interfaces';
import { TableRow } from 'data/content/model/elements/types';
import React from 'react';

export const TrEditor = (props: EditorProps<TableRow>) => {
  return <tr {...props.attributes}>{props.children}</tr>;
};
