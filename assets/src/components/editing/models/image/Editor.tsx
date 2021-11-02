import { EditorProps } from 'components/editing/models/interfaces';
import { getEditMode, updateModel } from 'components/editing/models/utils';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { Resizer } from 'components/misc/resizer/Resizer';
import * as ContentModel from 'data/content/model';
import { centeredAbove, displayModelToClassName } from 'data/content/utils';
import React, { useRef } from 'react';
import { Transforms } from 'slate';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import * as Settings from '../settings/Settings';
import { initCommands } from './commands';

export interface ImageProps extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: ImageProps): JSX.Element => {
  const { attributes, children, editor, model } = props;

  const focused = useFocused();
  const selected = useSelected();

  const parentRef = useRef<HTMLDivElement>(null);
  const imageRef = useRef<HTMLImageElement>(null);

  const editMode = getEditMode(editor);

  const commands = initCommands(model, (img) => onEdit(update(img)));

  const onEdit = (updated: ContentModel.Image) => {
    updateModel<ContentModel.Image>(editor, props.model, updated);
  };

  const update = (attrs: Partial<ContentModel.Image>) => Object.assign({}, model, attrs);

  const setCaption = (caption: string) => {
    onEdit(update({ caption }));
  };

  return (
    <div
      {...attributes}
      ref={parentRef}
      style={{ userSelect: 'none' }}
      className={'image-editor text-center ' + displayModelToClassName(model.display)}
    >
      <figure contentEditable={false}>
        <HoveringToolbar
          isOpen={() => focused && selected}
          showArrow
          target={
            <div>
              {ReactEditor.isFocused(editor) && selected && imageRef.current && (
                <Resizer
                  element={imageRef.current}
                  onResize={({ width, height }) => onEdit(update({ width, height }))}
                />
              )}
              <img
                width={model.width}
                height={model.height}
                ref={imageRef}
                onClick={() => {
                  ReactEditor.focus(editor);
                  Transforms.select(editor, ReactEditor.findPath(editor, model));
                }}
                className={displayModelToClassName(model.display)}
                src={model.src}
              />
            </div>
          }
          contentLocation={centeredAbove}
        >
          <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
        </HoveringToolbar>

        <figcaption contentEditable={false}>
          <Settings.Input
            editMode={editMode}
            value={model.caption}
            onChange={setCaption}
            editor={editor}
            model={model}
            placeholder="Set a caption for this image"
          />
        </figcaption>
      </figure>
      {children}
    </div>
  );
};
