import React from 'react';

import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityEditContext } from 'data/content/activity';
import { invokeCreationFunc } from 'components/activities/creation';
import * as Persistence from 'data/persistence/activity';

export type CreateActivityProps = {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  onAdd: (added: ActivityEditContext) => void;
  projectSlug: string;
};

const create = (
  projectSlug: string,
  editorDesc: EditorDesc,
  onAdded: (context: ActivityEditContext) => void,
) => {
  let model: any;
  let objectives: any;
  invokeCreationFunc(editorDesc.slug, {} as any)
    .then((createdModel) => {
      model = createdModel;
      return Persistence.createBanked(projectSlug, editorDesc.slug, createdModel, []);
    })
    .then((result: Persistence.Created) => {
      const activity: ActivityEditContext = {
        authoringElement: editorDesc.authoringElement as string,
        description: editorDesc.description,
        friendlyName: editorDesc.friendlyName,
        activitySlug: result.revisionSlug,
        typeSlug: editorDesc.slug,
        activityId: result.resourceId,
        title: editorDesc.friendlyName,
        model,
        objectives: {},
      };

      onAdded(activity);
    })
    .catch((err) => {
      // tslint:disable-next-line
      console.error(err);
    });
};

export const CreateActivity = (props: CreateActivityProps) => {
  const { editorMap, onAdd, projectSlug } = props;

  const handleAdd = (editorDesc: EditorDesc) => create(projectSlug, editorDesc, onAdd);

  const activityEntries = Object.keys(editorMap)
    .map((k: string) => editorMap[k])
    .filter(
      (editorDesc: EditorDesc) => editorDesc.globallyAvailable || editorDesc.enabledForProject,
    )
    .map((editorDesc: EditorDesc) => (
      <a
        onClick={handleAdd.bind(this, editorDesc)}
        className="dropdown-item"
        href="#"
        key={editorDesc.slug}
      >
        {editorDesc.friendlyName}
      </a>
    ));

  return (
    <div className="form-inline">
      <div className="dropdown">
        <button
          type="button"
          id="createButton"
          className="btn btn-primary dropdown-toggle btn-purpose mr-3"
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          Create New
        </button>
        <div className="dropdown-menu" aria-labelledby="createButton">
          {activityEntries}
        </div>
      </div>
    </div>
  );
};
