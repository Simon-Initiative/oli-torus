import { invokeCreationFunc } from 'components/activities/creation';
import { ActivityModelSchema } from 'components/activities/types';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { addActivity } from 'components/editing/toolbar/utils';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityReference, ResourceContext } from 'data/content/resource';
import * as Persistence from 'data/persistence/activity';
import React from 'react';
import guid from 'utils/guid';

interface Props {
  resourceContext: ResourceContext;
  onAddItem: AddCallback;
  editorMap: ActivityEditorMap;
  index: number;
}
export const AddActivity: React.FC<Props> = ({ resourceContext, onAddItem, editorMap, index }) => {
  const activityEntries = Object.keys(editorMap)
    .map((k: string) => {
      const editorDesc: EditorDesc = editorMap[k];
      const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;

      return enabled ? (
        <a
          href="#"
          key={editorDesc.slug}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={(_e) => addActivity(editorDesc, resourceContext, onAddItem, editorMap, index)}
        >
          <div className="type-label"> {editorDesc.friendlyName}</div>
          <div className="type-description"> {editorDesc.description}</div>
        </a>
      ) : null;
    })
    .filter((e) => e !== null);

  return (
    <>
      <div className="header">Activities...</div>
      <div className="list-group">{activityEntries}</div>
    </>
  );
};
