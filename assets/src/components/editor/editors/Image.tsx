import * as React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms, Editor, Range } from 'slate';
import * as ContentModel from 'data/content/model';
import { Maybe } from 'tsmonad';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { editorFor } from '../editors';
import { Attributes, getEditableAttributes } from './Attributes';

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

const command : Command = {
  execute: (editor: ReactEditor) => {
    const src = window.prompt('Enter the URL of the image:')
    if (!src) return;

    const image = ContentModel.create<ContentModel.Image>({ type: 'img', src, children: [{text: ''}], id: guid() });
    Transforms.insertNodes(editor, image);
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};

export const commandDesc : CommandDesc = {
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
  const { attributes, children } = props.editorContext;
  const { model } = props;

  const attrs = selected && focused
    ? getEditableAttributes(props.model)
    : [];
  const attributeEditor = attrs.length > 0
    ? <Attributes attributes={attrs} onEdit={a => props.onEdit(ContentModel.mutate(props.model, { [a.key]: a.value }))}/>
    : null;
  
  const imageStyle = {
    display: 'block',
    maxWidth: '100%',
    maxHeight: '500px',
    marginLeft: 'auto',
    marginRight: 'auto',
    boxShadow: (selected && focused) ? '0 0 0 2px blue' : 'none',
  };
  return (
    <div {...attributes}>
      <div contentEditable={false}>
        <img
          src={model.src}
          style={imageStyle}
        />
        {attributeEditor}
      </div>
      {children}
    </div>
  )
}
