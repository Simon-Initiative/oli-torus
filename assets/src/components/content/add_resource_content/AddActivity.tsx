import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { addActivity } from 'components/editing/toolbar/utils';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ResourceContext } from 'data/content/resource';
import React from 'react';

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
        <button
          key={editorDesc.slug}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={(_e) => {
            addActivity(editorDesc, resourceContext, onAddItem, editorMap, index);
            document.body.click();
          }}
        >
          <div className="type-label"> {editorDesc.friendlyName}</div>
          <div className="type-description"> {editorDesc.description}</div>
        </button>
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
