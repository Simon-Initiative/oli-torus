import React, { useRef, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms, Editor, Range } from 'slate';
import * as ContentModel from 'data/content/model';
import { Maybe } from 'tsmonad';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';

interface ImageSize {
  width: string;
  height: string;
}

type Position = {
  x: number;
  y: number;
}

const fetchImageSize = (src: string): Promise<ImageSize> => {
  const img = new (window as any).Image();
  return new Promise((resolve, reject) => {
    img.onload = () => {
      resolve({ height: img.height, width: img.width });
    };
    img.onerror = (err: any) => {
      reject(err);
    };
    img.src = src;
  });
};

const command: Command = {
  execute: (editor: ReactEditor) => {
    const src = window.prompt('Enter the URL of the image:')
    if (!src) return;

    const image = ContentModel.create<ContentModel.Image>({ type: 'img', src, children: [{ text: '' }], id: guid() });
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
  const imageElement = useRef(null);
  const handle = useRef(null);
  const { attributes, children } = props.editorContext;
  const { model } = props;
  const resizeRef = React.createRef();


  useEffect(() => {
    
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

  const centered = {
    display: 'flex',
    justifyContent: 'center',
    width: '100%'
  } as any;

  const handleStyle = {
    
    width: size[0] === -1 ? undefined : size[0],
    height: size[1] === -1 ? undefined : size[1],
    
  }

  const grab = {
    position: 'relative',
    left: (size[0] - 10) + 'px',
    top: '-12px',
    zIndex: 0,
    cursor: 'grab',
    color: 'darkblue',
    visibility: (selected && focused) ? 'visible' : 'hidden'
  } as any;

  const imageStyle = {
    display: 'block',
    maxWidth: '100%',
    maxHeight: '500px',
    marginLeft: 'auto',
    marginRight: 'auto',
    border: (selected && focused) ? 'solid 3px darkblue' : 'solid 3px white',
  } as any;
  return (
    <div {...attributes}>
      
      <div contentEditable={false}>
        
        <div style={centered}>
          <div ref={handle} style={handleStyle}>
            <img
              ref={imageElement}
              src={model.src}
              style={imageStyle}
            />
            <div><i style={grab} className="fas fa-square"></i></div>
            <div>&nbsp;</div>
          </div>
          
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ display: 'inline-block' }}><b>Caption:</b> {model.caption}</div>
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ display: 'inline-block' }}><b>Alt:</b> {model.alt}</div>
        </div>

      </div>
      {children}
    </div>
  )
}
