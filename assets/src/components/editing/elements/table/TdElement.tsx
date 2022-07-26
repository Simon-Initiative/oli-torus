import React from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { DropdownMenu } from './TableDropdownMenu';
import { cellAttributes } from './table-util';

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
