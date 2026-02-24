import React from 'react';
import { useCommandTargetable } from 'components/editing/elements/command_button/useCommandTargetable';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { EditorProps } from 'components/editing/elements/interfaces';
import { elementBorderStyle, useEditModelCallback } from 'components/editing/elements/utils';
import { WebpageSettings } from 'components/editing/elements/webpage/WebpageSettings';
import * as ContentModel from 'data/content/model/elements/types';
import { useElementSelected } from 'data/content/utils';

export interface Props extends EditorProps<ContentModel.Webpage> {}
export const WebpageEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = useEditModelCallback(props.model);
  useCommandTargetable(
    props.model.targetId,
    'Webpage',
    props.model.targetId || props.model.src || 'No command target id set',
  );

  const dimensions: { width?: number | string; height?: number | string } = {};
  if (props.model.width) {
    dimensions['width'] = props.model.width;
  }
  if (props.model.height) {
    dimensions['height'] = props.model.height;
  } else if (props.model.width) {
    // If we have a width, but no height, set the height to the same as width.
    dimensions['height'] = props.model.width;
  }

  const iframeClass = props.model.width ? '' : 'embed-responsive-item';
  const containerClass = props.model.width
    ? 'img-thumbnail'
    : 'embed-responsive embed-responsive-16by9 img-thumbnail';

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
        className={containerClass}
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
          className={iframeClass}
          {...dimensions}
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
