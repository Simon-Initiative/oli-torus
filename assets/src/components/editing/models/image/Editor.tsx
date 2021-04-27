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
import {
  MousePosition,
  useMousePosition,
} from 'components/editing/models/image/resizer/useMousePosition';
import { resizeHandleStyles } from 'components/editing/models/image/resizer/utils';
import { BoundingRect, Position } from 'components/editing/models/image/resizer/types';

// TODO:
// Save image width/height in model
// Constrain sizes to min/max
// Constrain proportions when dragging from corner
// Decide on re-saving image?

const isCorner = (position: Position) => ['nw', 'ne', 'sw', 'se'].includes(position);

const clientBoundingRect = (element: HTMLElement | null): BoundingRect | null => {
  if (!element) {
    return null;
  }
  const { left, top, width, height } = element.getBoundingClientRect();
  console.log('elem', left, top, width, height);
  return {
    top,
    left,
    width,
    height,
  };
};

const offsetBoundingRect = (element: HTMLElement | null): BoundingRect | null => {
  if (!element) {
    return null;
  }
  const { offsetTop, offsetLeft, offsetWidth, offsetHeight } = element;
  return {
    top: offsetTop,
    left: offsetLeft,
    width: offsetWidth,
    height: offsetHeight,
  };
};

const boundingRectFromMousePosition = (
  initialClientBoundingRect: BoundingRect | null,
  initialOffsetBoundingRect: BoundingRect | null,
  { x, y }: MousePosition,
  dragHandle: Position | undefined,
) => {
  if (!x || !y || !initialClientBoundingRect || !initialOffsetBoundingRect || !dragHandle) {
    return null;
  }
  const { top, left, width, height } = initialOffsetBoundingRect;
  let differenceLeft = 0,
    differenceTop = 0;

  switch (dragHandle) {
    case 'nw':
      differenceLeft = initialClientBoundingRect.left - x;
      differenceTop = initialClientBoundingRect.top - y;
      return {
        left: left - differenceLeft,
        top: top - differenceTop,
        width: width + differenceLeft,
        height: height + differenceTop,
      };
    case 'n':
      differenceTop = initialClientBoundingRect.top - y;
      return {
        left: left,
        top: top - differenceTop,
        width: width,
        height: height + differenceTop,
      };
    case 'ne':
      differenceLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      differenceTop = initialClientBoundingRect.top - y;
      return {
        left: left,
        top: top - differenceTop,
        width: width - differenceLeft,
        height: height + differenceTop,
      };
    case 'w':
      differenceLeft = initialClientBoundingRect.left - x;
      return {
        left: left - differenceLeft,
        top,
        width: width + differenceLeft,
        height: height,
      };
    case 'e':
      differenceLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      return {
        left: left,
        top: top,
        width: width - differenceLeft,
        height: height,
      };
    case 'sw':
      differenceLeft = initialClientBoundingRect.left - x;
      differenceTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left - differenceLeft,
        top: top,
        width: width + differenceLeft,
        height: height - differenceTop,
      };
    case 's':
      differenceTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left,
        top: top,
        width: width,
        height: height - differenceTop,
      };
    case 'se':
      differenceLeft = initialClientBoundingRect.left + initialClientBoundingRect.width - x;
      differenceTop = initialClientBoundingRect.top + initialClientBoundingRect.height - y;
      return {
        left: left,
        top: top,
        width: width - differenceLeft,
        height: height - differenceTop,
      };
    default:
      throw new Error('unhandled drag handle in Image Editor boundingRect');
  }
};

const newSize = (boundingRect: BoundingRect | null) => {
  if (!boundingRect) return undefined;
  const { width, height } = boundingRect;
  return { width, height };
};

// eslint-disable-next-line
export interface ImageProps extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: ImageProps): JSX.Element => {
  const { attributes, children, editor, model } = props;

  const focused = useFocused();
  const selected = useSelected();

  const imageRef = useRef<HTMLImageElement>(null);

  const [resizingFrom, setResizingFrom] = useState<Position | undefined>(undefined);

  const editMode = getEditMode(editor);

  const commands = initCommands(model, (img) => onEdit(update(img)));

  const onEdit = (updated: ContentModel.Image) => {
    updateModel<ContentModel.Image>(editor, props.model, updated);
  };

  const update = (attrs: Partial<ContentModel.Image>) => Object.assign({}, model, attrs);

  const setCaption = (caption: string) => {
    onEdit(update({ caption }));
  };

  const { x, y } = useMousePosition();

  const boundResizeStyles = resizeHandleStyles(
    resizingFrom === undefined
      ? offsetBoundingRect(imageRef.current)
      : boundingRectFromMousePosition(
          clientBoundingRect(imageRef.current),
          offsetBoundingRect(imageRef.current),
          { x, y },
          resizingFrom,
        ),
  );

  const onMouseDown = (position: Position) => (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    console.log('on mouse down');
    e.preventDefault();
    setResizingFrom(position);
  };

  const onMouseUp = (_e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    console.log('on mouse up, updating image size');
    // TODO: Update with new width and height of image
    console.log(
      'newsize',
      newSize(
        boundingRectFromMousePosition(
          clientBoundingRect(imageRef.current),
          offsetBoundingRect(imageRef.current),
          { x, y },
          resizingFrom,
        ),
      ),
    );
    setResizingFrom(undefined);
  };

  const resizeHandle = (position: Position) => (
    <div
      onMouseDown={onMouseDown(position)}
      className="resize-selection-box-handle"
      style={boundResizeStyles(position)}
    ></div>
  );

  let resizer;
  if (ReactEditor.isFocused(editor) && selected && imageRef.current) {
    resizer = (
      <>
        <div
          style={Object.assign(boundResizeStyles('border'), {
            position: 'absolute' as any,
            border: '2px solid rgb(0, 150, 253)',
            backgroundColor: 'rgba(0, 0, 0, 0)',
            zIndex: 30,
            borderColor: 'rgb(26, 115, 232)',
          })}
        ></div>
        {resizeHandle('nw')}
        {resizeHandle('n')}
        {resizeHandle('ne')}
        {resizeHandle('w')}
        {resizeHandle('e')}
        {resizeHandle('sw')}
        {resizeHandle('s')}
        {resizeHandle('se')}
      </>
    );
  } else {
    resizer = null;
  }

  return (
    <div
      onMouseUp={onMouseUp}
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
              {resizer}
              <img
                ref={imageRef}
                onClick={(e) => {
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
