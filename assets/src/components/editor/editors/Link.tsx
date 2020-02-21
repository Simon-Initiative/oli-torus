import React, { useState, useRef, useEffect } from 'react';
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

  useEffect(() => {
    if (isEditing) {
      setIsEditing(false);
    }
  });

  const onClick = () => {
    if (editMode) {
      setIsEditing(true);
    }
  };

  const containerStyle = {
    width: '350px',
    height: '100px',
    boxShadow: '0px 1px 3px 1px rgba(60, 64, 67, 0.15)',
    backgroundColor: 'white',
    borderColor: 'rgb(218, 220, 224)',
    borderRadius: '8px',
    padding: '8px',
    color: 'rgb(95, 99, 104)',
  };

  const form = (
    <div style={containerStyle}>

      <div>Link</div>
      <input type="text" className="form-control form-control-sm mb-2 mr-sm-2"
        placeholder="https://oli.cmu.edu"/>

      <button type="submit" className="btn btn-sm btn-primary mb-2">Apply</button>
    </div>
  );

  const popover = isEditing
    ?
    <Popover source={ref}>
      {form}
    </Popover>
    : null;

  return (
    <a {...attributes} onClick={onClick} href="#" ref={ref}>
      {popover}
      {children}
    </a>
  );
};

