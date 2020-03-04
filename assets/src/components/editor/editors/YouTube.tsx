import React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { LabelledTextEditor } from 'components/TextEditor';


const command: Command = {
  execute: (editor: ReactEditor) => {
    let src = window.prompt('Enter the id of the YouTube video:');
    if (!src) return;

    if (src.indexOf('?v=') !== -1) {
      src = src.substring(src.indexOf('?v=') + 3);
    }

    const youtube = ContentModel.create<ContentModel.YouTube>(
      { type: 'youtube', src, children: [{ text: '' }], id: guid() });
    Transforms.insertNodes(editor, youtube);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fab fa-youtube-square',
  description: 'YouTube',
  command,
};

export interface YouTubeProps extends EditorProps<ContentModel.YouTube> {
}

export const YouTubeEditor = (props: YouTubeProps) => {

  const selected = useSelected();
  const focused = useFocused();

  const { attributes, children, editor } = props;
  const { model } = props;

  const editMode = getEditMode(editor);

  const centered = {
    display: 'flex',
    justifyContent: 'center',
    width: '100%',
  } as any;

  const playerStyle = {
    display: 'block',
    width: '600px',
    height: '400px',
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

  const { src, height, width } = model;
  const fullSrc = 'https://www.youtube.com/embed/' + (src === '' ? 'zHIIzcWqsP0' : src);

  return (
    <div {...attributes}>

      <div contentEditable={false} style={{ userSelect: 'none' }}>

        <div style={centered}>
          <iframe style={playerStyle} src={fullSrc} height={height} width={width} />
        </div>

        <div style={{ marginLeft: '30px' }}>
          <LabelledTextEditor
            label="Caption"
            model={model.caption || ''}
            onEdit={onEditCaption}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
        <div style={{ marginLeft: '30px' }}>
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
