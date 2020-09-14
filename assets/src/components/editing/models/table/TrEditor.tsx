import React from 'react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';

export const TrEditor = (props: EditorProps<ContentModel.TableRow>) => {
  return (
    <tr {...props.attributes}>{props.children}</tr>
  );
};
