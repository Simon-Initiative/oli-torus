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
    const src = window.prompt('Enter the URL of the audio file:');
    if (!src) return;

    const audio = ContentModel.create<ContentModel.Audio>(
      { type: 'audio', src, children: [{ text: '' }], id: guid() });
    Transforms.insertNodes(editor, audio);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-music',
  description: 'Audio Clip',
  command,
};

export interface AudioProps extends EditorProps<ContentModel.Audio> {
}

export const AudioEditor = (props: AudioProps) => {

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

  const { src } = model;

  return (
    <div {...attributes}>

      <div contentEditable={false}>

        <div style={centered}>
          <audio style={playerStyle} src={src} controls />
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
