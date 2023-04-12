import { DropdownMenu } from './TableDropdownMenu';
import { cellAttributes } from './table-util';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';

export const ThEditor = (props: EditorProps<ContentModel.TableHeader>) => {
  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const maybeMenu =
    selected && focused ? <DropdownMenu editor={editor} model={props.model} /> : null;

  return (
    <th {...props.attributes} {...cellAttributes(props.model)}>
      {maybeMenu}
      {props.children}
    </th>
  );
};
