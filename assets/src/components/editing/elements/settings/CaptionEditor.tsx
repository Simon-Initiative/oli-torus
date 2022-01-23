import React from 'react';
import * as Settings from 'components/editing/elements/settings/Settings';
import { ModelElement } from 'data/content/model/elements/types';
import { getEditMode } from 'components/editing/elements/utils';
import { useSlate } from 'slate-react';

interface Props {
  onEdit: (caption: string) => void;
  model: ModelElement & { caption?: string };
}
export const CaptionEditor = (props: Props) => {
  const editor = useSlate();
  const editMode = getEditMode(editor);

  return (
    <div contentEditable={false}>
      <Settings.Input
        editMode={editMode}
        value={props.model.caption}
        onChange={props.onEdit}
        editor={editor}
        model={props.model}
        placeholder="Caption"
      />
    </div>
  );
};
