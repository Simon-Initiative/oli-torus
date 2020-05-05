import React from 'react';
import { TextEditor } from '../TextEditor';

export type TitleBarProps = {
  title: string,                  // The title of the resource
  editMode: boolean,              // Whether or not the user is editing
  onTitleEdit: (title: string) => void;
  children: any;
};

// Title bar component that allows title bar editing and displays
// any collection of child components
export const TitleBar = (props: TitleBarProps) => {

  const { editMode, title, onTitleEdit, children } = props;

  return (
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1 p-4 pl-5">
        <TextEditor
          onEdit={onTitleEdit}
          model={title}
          showAffordances={true}
          size="large"
          allowEmptyContents={false}
          editMode={editMode}/>
      </div>
      {children}
    </div>
  );
};
