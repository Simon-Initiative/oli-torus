import { ContentTable } from '../../../ContentTable';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { EditorProps } from 'components/editing/elements/interfaces';
import { updateModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { useSlate } from 'slate-react';

interface Props extends EditorProps<ContentModel.Table> {}
export const TableEditor = (props: Props) => {
  const editor = useSlate();

  const onEdit = (updated: Partial<ContentModel.Table>) =>
    updateModel<ContentModel.Table>(editor, props.model, updated);

  return (
    <div {...props.attributes} className="table-editor">
      <ContentTable model={props.model}>
        <tbody>{props.children}</tbody>
      </ContentTable>
      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};
