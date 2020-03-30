import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent, ResourceType, createDefaultStructuredContent } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { useLock } from '../utils/useLock';
import { useDeferredPersistence } from '../utils/useDeferredPersistence';
import { Editors } from './Editors';
import { Outline } from './Outline';
import { TextEditor } from '../TextEditor';
import { makeRequest } from 'data/persistence/common';

export type ResourceEditorProps = {
  resourceType: ResourceType,     // Page or assessment?
  authorId: number,               // The current author
  projectId: number,              // The current project
  resourceId: number,             // The current resource
  title: string,                  // The title of the resource
  content: ResourceContent[],     // Content of the resource
  objectives: Objective[],        // Attached objectives
  allObjectives: Objective[],     // All objectives
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
};

// The resource editor
export const ResourceEditor = (props: ResourceEditorProps) => {

  const { projectId, resourceId, content } = props;

  const lock = useLock(props.projectId, props.resourceId);
  const [state, setState] = useState(Immutable.List<ResourceContent>(content));
  const status = useDeferredPersistence(projectId, resourceId, state);
  const [title, setTitle] = useState(props.title);

  const onEdit = (content: Immutable.List<ResourceContent>) => {
    setState(content);
  };

  const onTitleEdit = (title: string) => {
    setTitle(title);
  };

  const onAddContent = () => setState(state.push(createDefaultStructuredContent()));

  const titleBar = (
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1">
        <TextEditor
          onEdit={onTitleEdit} model={title} showAffordances={true} editMode={lock.editMode}/>
      </div>
      <div className="">
      <div className="dropdown">
        <button className="btn dropdown-toggle" type="button"
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
  );

  // We only show the outline if there is more than one content element in the resource

  return (
    <div>
      {titleBar}
      <div className="d-flex flex-row align-items-baseline">
        {state.size > 1
          ? <Outline {...props} editMode={lock.editMode}
          onEdit={c => onEdit(c)} content={state}/>
          : null }
        <Editors {...props} editMode={lock.editMode}
          onEdit={c => onEdit(c)} content={state}/>
      </div>
    </div>
  );

};
