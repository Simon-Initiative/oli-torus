import React from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Resizable } from 'components/misc/resizable/Resizable';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { useElementSelected } from 'data/content/utils';
import { ImagePlaceholder } from 'components/editing/elements/image/block/ImagePlaceholder';
import { ImageSettings } from 'components/editing/elements/image/ImageSettings';

interface Props extends EditorProps<ContentModel.ImageBlock> {}

const percentageWidth = /^[0-9]+%$/;

const cssWidth = (width: number | string | undefined) => {
  if (!width) return undefined;
  if (typeof width === 'number') return width;
  if (typeof width !== 'string') return undefined;

  if (percentageWidth.test(width)) {
    return width;
  }

  const pixels = parseFloat(width);
  if (isNaN(pixels)) return undefined;
  return pixels;
};

export const ImageEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = useEditModelCallback(props.model);

  if (props.model.src === undefined) return <ImagePlaceholder {...props} />;

  return (
    <div {...props.attributes} contentEditable={false}>
      {props.children}
      <HoverContainer
        style={{ margin: '0 auto', width: 'fit-content', display: 'block' }}
        isOpen={selected}
        align="start"
        position="top"
        content={
          <ImageSettings
            model={props.model}
            onEdit={onEdit}
            commandContext={props.commandContext}
          />
        }
      >
        <div>
          <Resizable show={selected} onResize={({ width, height }) => onEdit({ width, height })}>
            <img
              src={props.model.src}
              style={{ maxWidth: cssWidth(props.model.width) ?? '100%' }}
            />
          </Resizable>
        </div>
      </HoverContainer>
      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};
