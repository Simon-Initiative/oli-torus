import React, { useRef, useState } from 'react';
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
import ResizeConsumer from 'components/common/resizer/ResizeConsumer';
import ResizeProvider from 'components/common/resizer/ResizeProvider';
// eslint-disable-next-line
export interface ImageProps extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: ImageProps) => {
  const { attributes, children, editor, model } = props;
  const [mousePosition, setMousePosition] = useState({ left: 0, top: 0 });

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

  // const imageStyle =
  //   ReactEditor.isFocused(editor) && selected
  //     ? { border: 'solid 3px lightblue', borderRadius: 0 }
  //     : { border: 'solid 3px transparent' };

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  console.log('model', model);
  const MARKER_SIZE = 4;
  const offsetByMarkerSize = ({ left, top, cursor }: any) => ({
    left: left - MARKER_SIZE,
    top: top - MARKER_SIZE,
    cursor: cursor,
  });

  let imageElement;
  if (ReactEditor.isFocused(editor) && selected && imageRef.current) {
    const { offsetTop, offsetLeft, offsetWidth, offsetHeight } = imageRef.current;
    const positionStyle = (
      position: 'border' | 'nw' | 'n' | 'ne' | 'w' | 'e' | 'sw' | 's' | 'se',
    ) => {
      switch (position) {
        case 'border':
          return { left: offsetLeft, top: offsetTop, width: offsetWidth, height: offsetHeight };
        case 'nw':
          return { left: offsetLeft, top: offsetTop, cursor: 'nw-resize' };
        case 'n':
          return {
            left: offsetLeft + Math.round(offsetWidth / 2),
            top: offsetTop,
            cursor: 'n-resize',
          };
        case 'ne':
          return { left: offsetLeft + offsetWidth, top: offsetTop, cursor: 'ne-resize' };
        case 'w':
          return {
            left: offsetLeft,
            top: offsetTop + Math.round(offsetHeight / 2),
            cursor: 'w-resize',
          };
        case 'e':
          return {
            left: offsetLeft + offsetWidth,
            top: offsetTop + Math.round(offsetHeight / 2),
            cursor: 'e-resize',
          };
        case 'sw':
          return { left: offsetLeft, top: offsetTop + offsetHeight, cursor: 'sw-resize' };
        case 's':
          return {
            left: offsetLeft + Math.round(offsetWidth / 2),
            top: offsetTop + offsetHeight,
            cursor: 's-resize',
          };
        case 'se':
          return {
            left: offsetLeft + offsetWidth,
            top: offsetTop + offsetHeight,
            cursor: 'se-resize',
          };
      }
    };

    console.log('mousePosition', mousePosition);

    imageElement = (
      <div>
        <div className="image-resize-selection-box-border" style={positionStyle('border')}></div>
        <div
          onMouseDown={(e) => {
            e.preventDefault();
            setMousePosition({ left: e.pageX, top: e.pageY });
          }}
          onMouseMove={(e) => {
            e.preventDefault();
            setMousePosition({ left: e.pageX, top: e.pageY });
          }}
          // onMouseUp={() => {}}
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('nw'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('n'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('ne'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('w'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('e'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('sw'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('s'))}
        ></div>
        <div
          className="image-resize-selection-box-handle"
          style={offsetByMarkerSize(positionStyle('se'))}
        ></div>
      </div>
    );
  } else {
    imageElement = null;
  }

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
            <ResizeProvider>
              <ResizeConsumer
                className="image-resize"
                onSizeChanged={(size) => undefined}
                updateDataAttributesBySize={(size) => console.log('size', size)}
              >
                {/* {imageElement} */}
                <img
                  ref={imageRef}
                  onClick={(e) => {
                    ReactEditor.focus(editor);
                    Transforms.select(editor, ReactEditor.findPath(editor, model));
                  }}
                  className={displayModelToClassName(model.display)}
                  // style={imageStyle}
                  src={model.src}
                />
              </ResizeConsumer>
            </ResizeProvider>
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
