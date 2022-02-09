import React from 'react';
import { useSelected, useFocused } from 'slate-react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';

export interface Props extends EditorProps<ContentModel.Webpage> {}
export const WebpageEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();

  const onEdit = onEditModel(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div
      {...props.attributes}
      style={borderStyle}
      contentEditable={false}
      className="embed-responsive embed-responsive-16by9 img-thumbnail webpage-editor"
    >
      {props.children}
      <iframe
        className="embed-responsive-item"
        src={props.model.src}
        allowFullScreen
        frameBorder={0}
      />
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
