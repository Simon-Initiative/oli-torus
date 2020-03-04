import React, { useRef, useEffect, useState } from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms, Editor as SlateEditor } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Maybe } from 'tsmonad';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { LabelledTextEditor } from 'components/TextEditor';

interface ImageSize {
  width: string;
  height: string;
}

const command: Command = {
  execute: (editor: ReactEditor) => {
    const src = window.prompt('Enter the URL of the image:');
    if (!src) return;

    const image = ContentModel.create<ContentModel.Image>(
      { type: 'img', src, children: [{ text: '' }], id: guid() });
    Transforms.insertNodes(editor, image);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-image',
  description: 'Image',
  command,
};

export interface ImageProps extends EditorProps<ContentModel.Image> {
}

export interface ImageState {
  size: Maybe<ImageSize>;
}

export const ImageEditor = (props: ImageProps) => {

  const selected = useSelected();
  const focused = useFocused();

  const [size, setSize] = useState([-1, -1]);
  const [last, setLast] = useState([-1, -1]);
  const [isResizing, setIsResizing] = useState(false);

  const imageElement = useRef(null);
  const handle = useRef(null);
  const { attributes, children, editor } = props;
  const { model } = props;

  const editMode = getEditMode(editor);

  useEffect(() => {

    // Do this just once, to set the state based on the size of the image
    if (size[0] === -1) {

      const target = imageElement.current as any;
      if (target === null) {
        return;
      }

      if (target instanceof HTMLImageElement) {
        const image = target as HTMLImageElement;

        if (handle !== null && handle.current !== null && image.width !== 0) {
          setSize([image.width, image.height]);
        }
      }
    }

  });

  // up, down, and move callbacks for managing the click and drag resize

  const down = () => setIsResizing(true);

  const up = (e: MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();

    if (isResizing) {
      setIsResizing(false);
      const height = size[1];
      const width = size[0];

      const { editor, model } = props;
      updateModel(editor, model, { height, width });

    }
  };

  const move = (e: MouseEvent) => {
    if (isResizing) {

      const { clientX, clientY } = e;

      if (last[0] === -1) {
        setLast([clientX, clientY]);
      } else {

        const [lastX, lastY] = last;
        const xDiff = clientX - lastX;
        const yDiff = clientY - lastY;

        setLast([clientX, clientY]);

        const [width, height] = size;
        const ar = height / width;
        const w = width + xDiff;
        const h = ar * width;
        setSize([w, h]);
      }
    }
  };


  const centered = {
    display: 'flex',
    justifyContent: 'center',
    width: '100%',
  } as any;

  const handleStyle = {
    width: size[0] === -1 ? undefined : size[0],
    height: size[1] === -1 ? undefined : size[1],
  };

  const grab = {
    position: 'relative',
    left: (size[0] - 10) + 'px',
    top: '-12px',
    zIndex: 0,
    cursor: isResizing ? 'col-resize' : 'grab',
    color: 'darkblue',
    visibility: (selected && focused) ? 'visible' : 'hidden',
  } as any;

  const baseStyle = {
    cursor: isResizing ? 'col-resize' : undefined,
  };

  const imageStyle = {
    display: 'block',
    maxWidth: '100%',
    maxHeight: '500px',
    marginLeft: 'auto',
    marginRight: 'auto',
    border: (selected && focused) ? 'solid 3px darkblue' : 'solid 3px white',
  } as any;

  const onEditCaption = (caption: string) => updateModel(editor, model, { caption });
  const onEditAlt = (alt: string) => updateModel(editor, model, { alt });

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div {...attributes} onMouseMove={move} onMouseUp={up as any} style={baseStyle}>

      <div contentEditable={false} style={{ userSelect: 'none' }}>

        <div style={centered}>
          <div ref={handle} style={handleStyle}>
            <img
              ref={imageElement}
              src={model.src}
              style={imageStyle}
              draggable={false}
            />
            <div onMouseDown={down} ><i style={grab} className="fas fa-square"></i></div>
            <div>&nbsp;</div>
          </div>

        </div>

        <div style={{ textAlign: 'center' }}>
          <LabelledTextEditor
            label="Caption"
            model={model.caption || ''}
            onEdit={onEditCaption}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
        <div style={{ textAlign: 'center' }}>
          <LabelledTextEditor
            label="Alt"
            model={model.alt || ''}
            onEdit={onEditAlt}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
      </div>

      {children}
    </div>
  );
};
