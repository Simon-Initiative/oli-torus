import React from 'react';
import { ActivityModelSchema, invokeCreationFunc } from 'components/activities';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityReference, ResourceContext } from 'data/content/resource';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';
import { ResourceChoice } from './ResourceChoice';

interface Props {
  onSetTip: (tip: string) => void;
  onResetTip: () => void;
  resourceContext: ResourceContext;
  onAddItem: AddCallback;
  editorMap: ActivityEditorMap;
  index: number[];
}
export const AddActivity: React.FC<Props> = ({
  onSetTip,
  onResetTip,
  resourceContext,
  onAddItem,
  editorMap,
  index,
}) => {
  const activityEntries = Object.keys(editorMap)
    .map((k: string) => {
      const editorDesc: EditorDesc = editorMap[k];
      const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;

      return enabled ? (
        <ResourceChoice
          key={editorDesc.id}
          onClick={() => {
            addActivity(editorDesc, resourceContext, onAddItem, editorMap, index);
            document.body.click();
          }}
          onHoverStart={() => onSetTip(editorDesc.description)}
          onHoverEnd={() => onResetTip()}
          disabled={false}
          icon={editorDesc.icon}
          label={editorDesc.petiteLabel}
        />
      ) : null;
    })
    .filter((e) => e !== null);

  return (
    <div className="d-flex flex-column">
      <div className="resource-choice-header ml-3">Question types</div>
      <div className="resource-choices activities">{activityEntries}</div>
    </div>
  );
};

const addActivity = (
  editorDesc: EditorDesc,
  resourceContext: ResourceContext,
  onAddItem: AddCallback,
  editorMap: ActivityEditorMap,
  index: number[],
) => {
  let model: ActivityModelSchema;

  invokeCreationFunc(editorDesc.authoringElement, resourceContext)
    .then((createdModel) => {
      model = createdModel;

      return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, []);
    })
    .then((result: Persistence.Created) => {
      const resourceContent: ActivityReference = {
        type: 'activity-reference',
        id: guid(),
        activitySlug: result.revisionSlug,
        children: [],
      };

      // For every part that we find in the model, we attach the selected
      // objectives to it
      const parts = model.authoring.parts || [];
      const objectives = parts
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
        optionalContentTypes: resourceContext.optionalContentTypes,
        model,
        objectives,
        tags: [],
        variables: editorDesc.variables,
      });
    })
    .catch((err) => {
      // tslint:disable-next-line
      console.error(err);
    });
};
