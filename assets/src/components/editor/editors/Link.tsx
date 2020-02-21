import React, { useState, useRef } from 'react';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';

import { EditorProps } from './interfaces';
import { Popover } from './Popover';


export interface LinkProps extends EditorProps<ContentModel.Hyperlink> {
}

export const LinkEditor = (props: LinkProps) => {

  const { attributes, children, editor } = props;
  const [isEditing, setIsEditing] = useState(false);
  const ref = useRef(null);
  const { model } = props;

  const editMode = getEditMode(editor);

  const onClick = () => {
    if (editMode) {
      setIsEditing(true);
    }
  };

  const popover = isEditing
    ?
    <Popover source={ref}>
      <div>Hello</div>
    </Popover>
    : null;

  return (
    <a {...attributes} onClick={onClick} href="#" ref={ref}>
      {popover}
      {children}
    </a>
  );
};

