import React from 'react';
import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { EditorProps } from './interfaces';
import { Command, CommandDesc } from '../interfaces';
import { updateModel } from './utils';

import guid from 'utils/guid';

const wrapLink = (editor: ReactEditor, link: ContentModel.Hyperlink) => {
  Transforms.wrapNodes(editor, link, { split: true });
  Transforms.collapse(editor, { edge: 'end' });
};

const command: Command = {
  execute: (editor: ReactEditor) => {
    const href = window.prompt('Enter the URL of the link:');
    if (!href) return;

    const link = ContentModel.create<ContentModel.Hyperlink>(
      { type: 'a', href, target: 'self', children: [{ text: '' }], id: guid() });

    wrapLink(editor, link);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};


export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-link',
  description: 'Link',
  command,
};



export interface LinkProps extends EditorProps<ContentModel.Hyperlink> {
}

export const LinkEditor = (props: LinkProps) => {

  const { attributes, children, editor, model } = props;

  const onClick = (e: MouseEvent) => {
    e.preventDefault();

    const href = window.prompt('Enter the URL of the link:', model.href);
    if (!href || href === model.href) return;

    updateModel<ContentModel.Hyperlink>(editor, model, { href });
  };

  return (
    <a {...attributes} href="#" onClick={onClick}>
      {children}
    </a>
  );
};
