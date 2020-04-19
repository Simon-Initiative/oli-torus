import React from 'react';
import { ResourceContent, Activity, ResourceContext, ActivityReference,
  ActivityPurpose, createDefaultStructuredContent } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { invokeCreationFunc } from 'components/activities/creation';
import * as Persistence from 'data/persistence/activity';
import guid from 'utils/guid';

type AddCallback = (content: ResourceContent, a? : Activity) => void;

// Component that presents a drop down to use to add structure
// content or the any of the registered activities
export const AddResourceContent = (
  { editMode, onAddItem, editorMap, resourceContext }
  : {editMode: boolean, onAddItem: AddCallback,
    editorMap: ActivityEditorMap, resourceContext: ResourceContext }) => {

  const handleAdd = (editorDesc: EditorDesc) => {

    let model : ActivityModelSchema;
    invokeCreationFunc(editorDesc.slug, resourceContext)
      .then((createdModel) => {
        model = createdModel;
        return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model);
      })
      .then((result: Persistence.Created) => {

        const resourceContent : ActivityReference = {
          type: 'activity-reference',
          id: guid(),
          activitySlug: result.revisionSlug,
          purpose: ActivityPurpose.none,
          children: [],
        };

        const activity : Activity = {
          type: 'activity',
          activitySlug: result.revisionSlug,
          typeSlug: editorDesc.slug,
          model,
        };

        onAddItem(resourceContent, activity);
      })
      .catch((err) => {
        // console.log(err);
      });
  };

  const content = <a className="dropdown-item" key="content"
    onClick={() => onAddItem(createDefaultStructuredContent())}>Content</a>;

  const activityEntries = Object
    .keys(editorMap)
    .map((k: string) => {
      const editorDesc : EditorDesc = editorMap[k];
      return (
        <a className="dropdown-item"
          key={editorDesc.slug}
          onClick={handleAdd.bind(this, editorDesc)}>{editorDesc.friendlyName}</a>
      );
    });

  return (
    <div className="dropdown">
      <button className={`btn dropdown-toggle ${editMode ? '' : 'disabled'}`} type="button"
        id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
        +
      </button>
      <div className="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
        {[content, ...activityEntries]}
      </div>
    </div>
  );
};
