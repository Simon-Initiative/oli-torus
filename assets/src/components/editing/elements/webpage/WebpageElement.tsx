import React from 'react';
import { elementBorderStyle, useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { useElementSelected } from 'data/content/utils';
import { classNames } from 'utils/classNames';
import { WebpageSettings } from 'components/editing/elements/webpage/WebpageSettings';

export interface Props extends EditorProps<ContentModel.Webpage> {}
export const WebpageEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = useEditModelCallback(props.model);

  return (
    <div {...props.attributes} className="webpage-editor">
      {props.children}
      <div
        contentEditable={false}
        style={{
          maxWidth: props.model.width ?? '100%',
          position: 'relative',
          overflow: 'visible',
          ...elementBorderStyle(selected),
        }}
        className={classNames('embed-responsive', 'embed-responsive-16by9', 'img-thumbnail')}
      >
        <div
          style={{
            display: selected ? 'block' : 'none',
            position: 'absolute',
            top: 0,
            zIndex: 1,
          }}
        >
          <WebpageSettings
            model={props.model}
            onEdit={onEdit}
            commandContext={props.commandContext}
          />
        </div>

        <iframe
          className="embed-responsive-item"
          src={props.model.src}
          allowFullScreen
          frameBorder={0}
        />
      </div>

      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};
