import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent, ResourceType } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { useLock } from '../utils/useLock';
import { useDeferredPersistence } from '../utils/useDeferredPersistence';
import { Editors } from './Editors';
import { Outline } from './Outline';

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

  const onEdit = (content: Immutable.List<ResourceContent>) => {
    setState(content);
  };

  // We only show the outline if there is more than one content element in the resource
  if (state.size > 0) {
    return (
      <div>
        <p>{status.type}</p>
        <div className="d-flex flex-row align-items-baseline">
          <Outline {...props} editMode={lock.editMode}
            onEdit={c => onEdit(c)} content={state}/>
          <Editors {...props} editMode={lock.editMode}
            onEdit={c => onEdit(c)} content={state}/>
        </div>
      </div>
    );
  }

  return (
    <Editors {...props} editMode={lock.editMode} onEdit={c => onEdit(c)} content={state}/>
  );
};
