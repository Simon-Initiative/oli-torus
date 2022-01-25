import React from 'react';
import { ReactEditor, useSelected, useFocused, useSlate } from 'slate-react';
import { Transforms } from 'slate';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';

export interface Props extends EditorProps<ContentModel.Webpage> {}
export const WebpageEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();

  const onEdit = onEditModel(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div
      {...props.attributes}
      className={'embed-responsive embed-responsive-16by9 img-thumbnail position-relative'}
      style={borderStyle}
      contentEditable={false}
      onClick={(_e) => {
        ReactEditor.focus(editor);
        Transforms.select(editor, ReactEditor.findPath(editor, props.model));
      }}
    >
      {props.children}
      <iframe
        onMouseDown={(e) => e.preventDefault()}
        className="embed-responsive-item"
        src={props.model.src}
        allowFullScreen
      />
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
