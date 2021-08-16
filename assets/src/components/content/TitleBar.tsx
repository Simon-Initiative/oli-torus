import React from 'react';
import { TextEditor } from '../TextEditor';
import { classNames } from 'utils/classNames';

export type TitleBarProps = {
  title: string; // The title of the resource
  editMode: boolean; // Whether or not the user is editing
  onTitleEdit: (title: string) => void;
  children: any;
  className?: string;
};

// Title bar component that allows title bar editing and displays
// any collection of child components
export const TitleBar = (props: TitleBarProps) => {
  const { editMode, className, title, onTitleEdit, children } = props;

  return (
    <div
      className={classNames([
        'TitleBar',
        'd-flex flex-column flex-md-row align-items-baseline my-2',
        className,
      ])}
    >
      <div className="d-flex align-items-center flex-grow-1 mr-2">
        <TextEditor
          onEdit={onTitleEdit}
          model={title}
          showAffordances={true}
          size="large"
          allowEmptyContents={false}
          editMode={editMode}
        />
      </div>
      {children}
    </div>
  );
};
