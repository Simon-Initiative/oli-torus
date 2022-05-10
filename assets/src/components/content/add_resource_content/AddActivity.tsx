import { ActivityModelSchema, invokeCreationFunc } from 'components/activities';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityReference, ResourceContext } from 'data/content/resource';
import React from 'react';
import guid from 'utils/guid';
import * as Persistence from 'data/persistence/activity';

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

const addActivity = (
  editorDesc: EditorDesc,
  resourceContext: ResourceContext,
  onAddItem: AddCallback,
  editorMap: ActivityEditorMap,
  index: number,
) => {
  let model: ActivityModelSchema;

  invokeCreationFunc(editorDesc.slug, resourceContext)
    .then((createdModel) => {
      model = createdModel;

      return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, []);
    })
    .then((result: Persistence.Created) => {
      const resourceContent: ActivityReference = {
        type: 'activity-reference',
        id: guid(),
        activitySlug: result.revisionSlug,
        purpose: 'none',
        children: [],
      };

      // For every part that we find in the model, we attach the selected
      // objectives to it
      const objectives = model.authoring.parts
        .map((p: any) => p.id)
        .reduce((p: any, id: string) => {
          p[id] = [];
          return p;
        }, {});

      const editor = editorMap[editorDesc.slug];

      onAddItem(resourceContent, index, {
        authoringElement: editor.authoringElement as string,
        description: editor.description,
        friendlyName: editor.friendlyName,
        activitySlug: result.revisionSlug,
        typeSlug: editorDesc.slug,
        activityId: result.resourceId,
        title: editor.friendlyName,
        model,
        objectives,
        tags: [],
      });
    })
    .catch((err) => {
      // tslint:disable-next-line
      console.error(err);
    });
};
