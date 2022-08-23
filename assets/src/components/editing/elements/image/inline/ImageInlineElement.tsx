import React from 'react';
import { elementBorderStyle, useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useElementSelected } from 'data/content/utils';
import { ImageSettings } from 'components/editing/elements/image/ImageSettings';

interface Props extends EditorProps<ContentModel.ImageInline> {}
export const ImageInlineEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = useEditModelCallback(props.model);

  return (
    <span {...props.attributes} onMouseDown={(e) => e.stopPropagation()}>
      {props.children}
      <span contentEditable={false} style={{ position: 'relative', display: 'inline-block' }}>
        <span
          style={{
            display: selected ? 'inline-block' : 'none',
            position: 'absolute',
            top: 'calc(100% + 8px)',
            zIndex: 1,
          }}
        >
          <ImageSettings
            model={props.model}
            onEdit={onEdit}
            commandContext={props.commandContext}
          />
        </span>
        <img
          src={props.model.src}
          style={{ maxWidth: props.model.width ?? '100%', ...elementBorderStyle(selected) }}
        />
      </span>
    </span>
  );
};
