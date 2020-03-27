import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent, ResourceType } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';
import { Editors } from './Editors';
import { Outline } from './Outline';

export type ResourceEditorProps = {
  resourceType: ResourceType,     // Page or assessment?
  authorId: number,               // The current author
  projectId: number,              // The current project
  resourceId: number,             // The current resource
  editMode: boolean,              // Whether or not we can edit
  title: string,                  // The title of the resource
  content: ResourceContent[],     // Content of the resource
  objectives: Objective[],        // Attached objectives
  allObjectives: Objective[],     // All objectives
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
};

// The resource editor
export const ResourceEditor = (props: ResourceEditorProps) => {

  const [content, setContent] = useState(Immutable.List<ResourceContent>(props.content));

  const onEdit = (c: Immutable.List<ResourceContent>) => {
    setContent(c);
  };

  // We only show the outline if there is more than one content element in the resource
  if (content.size > 0) {
    return (
      <div className="d-flex flex-row align-items-baseline">
        <Outline {...props} onEdit={c => onEdit(c)} content={content}/>
        <Editors {...props} onEdit={c => onEdit(c)} content={content}/>
      </div>
    );
  }

  return (
    <Editors {...props} onEdit={c => onEdit(c)} content={content}/>
  );
};
