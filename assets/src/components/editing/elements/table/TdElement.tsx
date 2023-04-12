import { DropdownMenu } from './TableDropdownMenu';
import { cellAttributes } from './table-util';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';

export const TdEditor = (props: EditorProps<ContentModel.TableData>) => {
  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const maybeMenu =
    selected && focused ? <DropdownMenu editor={editor} model={props.model} /> : null;

  return (
    <td {...props.attributes} {...cellAttributes(props.model)}>
      {maybeMenu}
      {props.children}
    </td>
  );
};
