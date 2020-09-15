import React from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import { DropdownMenu } from './DropdownMenu';

export const TdEditor = (props: EditorProps<ContentModel.TableData>) => {

  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const maybeMenu = selected && focused
    ? <DropdownMenu editor={editor} model={props.model} /> : null;

  return (
    <td {...props.attributes}>
      {maybeMenu}
      {props.children}
    </td>
  );
};
