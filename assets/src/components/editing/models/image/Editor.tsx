import React, { useRef } from 'react';
import { useFocused, useSelected, ReactEditor } from 'slate-react';
import { updateModel, getEditMode } from 'components/editing/models/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import * as Settings from '../settings/Settings';
import { Transforms } from 'slate';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { initCommands } from './commands';
import { displayModelToClassName } from 'data/content/utils';
import { Resizer } from 'components/misc/resizer/Resizer';

// eslint-disable-next-line
export interface ImageProps extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: ImageProps): JSX.Element => {
  const { attributes, children, editor, model } = props;

  const focused = useFocused();
  const selected = useSelected();

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
          contentLocation={({ popoverRect, targetRect }) => {
            return {
              top: targetRect.top + window.pageYOffset - 50,
              left:
                targetRect.left + window.pageXOffset + targetRect.width / 2 - popoverRect.width / 2,
            };
          }}
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
