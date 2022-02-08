import React from 'react';
import * as Settings from 'components/editing/elements/common/settings/Settings';
import { ModelElement } from 'data/content/model/elements/types';

interface Props {
  onEdit: (caption: string) => void;
  model: ModelElement & { caption?: string };
}
export const CaptionEditor = (props: Props) => {
  return (
    <div contentEditable={false}>
      <Settings.Input
        value={props.model.caption}
        onChange={props.onEdit}
        model={props.model}
        placeholder="Caption"
      />
    </div>
  );
};
