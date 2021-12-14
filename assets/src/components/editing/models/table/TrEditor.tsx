import React from 'react';
import { EditorProps } from 'components/editing/models/interfaces';
import { TableRow } from 'data/content/model/elements/types';

export const TrEditor = (props: EditorProps<TableRow>) => {
  return <tr {...props.attributes}>{props.children}</tr>;
};
