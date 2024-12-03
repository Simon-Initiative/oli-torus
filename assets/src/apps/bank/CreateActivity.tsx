import React, { useState } from 'react';
import { invokeCreationFunc } from 'components/activities/creation';
import { BulkQuestionsImport } from 'apps/authoring/components/Modal/BulkQuestionsImport';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import * as Persistence from 'data/persistence/activity';
import { CreationData } from 'components/activities';
import { Objective } from 'data/content/objective';
import { Tag } from 'data/content/tags';

export type CreateActivityProps = {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  onAdd: (added: ActivityEditContext) => void;
  projectSlug: string;
  allObjectives: Objective[]; // All objectives
  allTags: Tag[]; // All tags
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

const createBulk = async (
  projectSlug: string,
  editorMap: ActivityEditorMap,
  bulkImportData: CreationData[],
  onAdd: (added: ActivityEditContext) => void,
) => {
  console.log('editorMap', editorMap);
  for (const data of bulkImportData) {
    let editorDesc: EditorDesc | null = null;
    switch (data.type.toLowerCase()) {
      case 'mcq':
         editorDesc = editorMap['oli_multiple_choice'];
        break;
      case 'cata':
         editorDesc = editorMap['oli_check_all_that_apply'];
        break;
      case 'ordering':
        editorDesc = editorMap['oli_ordering'];
        break;
      case 'number':
      case 'text':
      case 'paragraph':
      case 'math':
        editorDesc = editorMap['oli_short_answer'];
        break;
      default:
        console.error('unknown type', data.type);
        break;
    }
    if (editorDesc) {
      const model = await invokeCreationFunc(editorDesc.slug, {creationData: data} as any)
        .then((createdModel) => {
          return createdModel
        })
        .catch((err) => {
          // tslint:disable-next-line
          console.error(err);
        });
      console.log('createdModel', JSON.stringify(model));
    }
  }
};

export const CreateActivity = (props: CreateActivityProps) => {
  const { editorMap, onAdd, projectSlug } = props;
  const [modalShow, setModalShow] = useState(false);

  const handleAdd = (editorDesc: EditorDesc) => create(projectSlug, editorDesc, onAdd);

  const handleBulkAdd = (bulkImportData: CreationData[]) => {
    setModalShow(false);
    createBulk(projectSlug, editorMap, bulkImportData, onAdd);
  };

  let activityEntries = Object.keys(editorMap)
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

  activityEntries = [
    ...activityEntries,
    <a
      onClick={() => setModalShow(true)}
      className="dropdown-item"
      href="#"
      key="bulk_import_from_csv"
    >
      Bulk Import from CSV
    </a>,
  ];

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
      <BulkQuestionsImport
        onCancel={() => setModalShow(false)}
        onUpload={(bulkImportData: CreationData[]) => handleBulkAdd(bulkImportData)}
        show={modalShow}
      />
    </div>
  );
};
