import React from 'react';
import { updateModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { useSlate } from 'slate-react';
import { ContentTable } from '../../../ContentTable';

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
