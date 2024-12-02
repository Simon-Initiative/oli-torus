import React from 'react';
import { invokeCreationFunc } from 'components/activities/creation';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
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
  invokeCreationFunc(editorDesc.slug, {} as any)
    .then((createdModel) => {
      model = createdModel;
      return Persistence.createBanked(projectSlug, editorDesc.slug, createdModel, []);
    })
    .then((result: Persistence.Created) => {
      const objectives = model.authoring.parts
        .map((p: any) => {
          return p.id;
        })
        .reduce((m: any, id: any) => {
          m[id] = [];
          return m;
        }, {});

      const activity: ActivityEditContext = {
        authoringElement: editorDesc.authoringElement as string,
        description: editorDesc.description,
        friendlyName: editorDesc.friendlyName,
        activitySlug: result.revisionSlug,
        typeSlug: editorDesc.slug,
        activityId: result.resourceId,
        title: editorDesc.friendlyName,
        model,
        objectives,
        tags: [],
        variables: editorDesc.variables,
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
          className="btn btn-primary dropdown-toggle"
          data-bs-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          Create New
          <svg
            aria-hidden="true"
            focusable="false"
            data-prefix="fas"
            data-icon="caret-down"
            className="w-2 ml-2"
            role="img"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 320 512"
          >
            <path
              fill="currentColor"
              d="M31.3 192h257.3c17.8 0 26.7 21.5 14.1 34.1L174.1 354.8c-7.8 7.8-20.5 7.8-28.3 0L17.2 226.1C4.6 213.5 13.5 192 31.3 192z"
            ></path>
          </svg>
        </button>
        <div className="dropdown-menu" aria-labelledby="createButton">
          {activityEntries}
        </div>
      </div>
    </div>
  );
};
