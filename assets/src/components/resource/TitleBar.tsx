
import React from 'react';
import { ResourceContent, createDefaultStructuredContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { TextEditor } from '../TextEditor';

export type TitleBarProps = {
  title: string,                  // The title of the resource
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  editMode: boolean,              // Whether or not the user is editing
  onTitleEdit: (title: string) => void;
  onAddItem: (content: ResourceContent) => void;
  canUndo: boolean;
  canRedo: boolean;
  onUndo: () => void;
  onRedo: () => void;
};

// The resource editor
export const TitleBar = (props: TitleBarProps) => {

  const { editMode, title, onTitleEdit, onAddItem, canUndo, canRedo } = props;

  const onAddContent = () => onAddItem(createDefaultStructuredContent());

  return (
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1">
        <TextEditor
          onEdit={onTitleEdit} model={title} showAffordances={true} editMode={editMode}/>
      </div>

      <div className="btn-group btn-group-sm" role="group" aria-label="Undo redo creation">
        <button className={`btn ${canUndo ? '' : 'disabled'}`} type="button" onClick={props.onUndo}>
          <span><i className="fas fa-undo"></i></span>
        </button>
        <button className={`btn ${canRedo ? '' : 'disabled'}`} type="button" onClick={props.onRedo}>
        <span><i className="fas fa-redo"></i></span>
        </button>
        <div className="">
          <div className="dropdown">
            <button className={`btn dropdown-toggle ${editMode ? '' : 'disabled'}`} type="button"
              id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
              +
            </button>
            <div className="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
              <a className="dropdown-item" onClick={onAddContent}>Content</a>
              <a className="dropdown-item disabled" href="#">Multiple Choice</a>
              <a className="dropdown-item disabled" href="#">Short Answer</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
