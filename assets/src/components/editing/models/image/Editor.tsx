import React from 'react';
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

export interface ImageProps extends EditorProps<ContentModel.Image> { }
export const ImageEditor = (props: ImageProps) => {

  const { attributes, children, editor, model } = props;

  const focused = useFocused();
  const selected = useSelected();

  const editMode = getEditMode(editor);

  const commands = initCommands(model, img => onEdit(update(img)));

  const onEdit = (updated: ContentModel.Image) => {
    updateModel<ContentModel.Image>(editor, props.model, updated);
  };

  const update = (attrs: Partial<ContentModel.Image>) =>
    Object.assign({}, model, attrs);

  const setCaption = (caption: string) => {
    onEdit(update({ caption }));
  };

  const imageStyle = ReactEditor.isFocused(editor) && selected
    ? { border: 'solid 3px lightblue', borderRadius: 0 } : { border: 'solid 3px transparent' };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div
      {...attributes}
      contentEditable={false}
      style={{ userSelect: 'none' }}
      className={'image-editor text-center ' + displayModelToClassName(model.display)}>
      <figure>
        <HoveringToolbar
          isOpen={e => focused && selected}
          showArrow
          target={
            <img
              onClick={(e) => {
                ReactEditor.focus(editor);
                Transforms.select(editor, ReactEditor.findPath(editor, model));
              }}
              className={displayModelToClassName(model.display)}
              style={imageStyle}
              src={model.src}
            />
          }
          contentLocation={({ popoverRect, targetRect }) => {
            return {
              top: targetRect.top + window.pageYOffset - 50,
              left: targetRect.left + window.pageXOffset
                + targetRect.width / 2 - popoverRect.width / 2,
            };
          }}>
          <FormattingToolbar
            commandDescs={commands}
            commandContext={props.commandContext} />
        </HoveringToolbar>

        <figcaption contentEditable={false}>
          <Settings.Input
            editMode={editMode}
            value={model.caption}
            onChange={setCaption}
            editor={editor}
            model={model}
            placeholder="Enter an optional caption for this image"
          />
        </figcaption>
      </figure>
      {children}
    </div>
  );
};
