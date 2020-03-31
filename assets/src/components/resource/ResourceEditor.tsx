import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent, ResourceType } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { useLock } from '../utils/useLock';
import { useDeferredPersistence } from '../utils/useDeferredPersistence';
import { Editors } from './Editors';
import { Outline } from './Outline';
import { TitleBar } from './TitleBar';
import { ProjectId, ResourceId } from 'data/types';
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

function issueSaveRequest(project: ProjectId, resource: ResourceId, body: any) {
  const params = {
    method: 'PUT',
    body,
    url: `/project/${project}/${resource}/edit`,
  };

  return makeRequest(params);
}

// The resource editor
export const ResourceEditor = (props: ResourceEditorProps) => {

  const { projectId, resourceId, content, editorMap } = props;

  const lock = useLock(props.projectId, props.resourceId);
  const [state, setState] = useState(Immutable.List<ResourceContent>(content));
  const status = useDeferredPersistence(
    issueSaveRequest.bind(undefined, projectId, resourceId), state);
  const [title, setTitle] = useState(props.title);

  const onEdit = (content: Immutable.List<ResourceContent>) => {
    setState(content);
  };

  const onTitleEdit = (title: string) => {
    setTitle(title);
    issueSaveRequest(projectId, resourceId, { title });
  };

  const onAddItem = (c : ResourceContent) => setState(state.push(c));

  return (
    <div>
      <TitleBar
        title={title}
        onTitleEdit={onTitleEdit}
        onAddItem={onAddItem}
        editMode={lock.editMode}
        editorMap={editorMap}/>

      <div className="d-flex flex-row align-items-baseline">
        {
        // We only show the outline if there is more than one content element in the resource
        state.size > 1
          ? <Outline {...props} editMode={lock.editMode}
          onEdit={c => onEdit(c)} content={state}/>
          : null
        }
        <Editors {...props} editMode={lock.editMode}
          onEdit={c => onEdit(c)} content={state}/>
      </div>
    </div>
  );

};
