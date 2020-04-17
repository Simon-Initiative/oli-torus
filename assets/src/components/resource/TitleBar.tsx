
import React from 'react';
import { ResourceContent, Activity, ResourceContext, ActivityReference,
  ActivityPurpose, createDefaultStructuredContent } from 'data/content/resource';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { ActivityModelSchema } from 'components/activities/types';
import { TextEditor } from '../TextEditor';
import { invokeCreationFunc } from 'components/activities/creation';
import { createActivity, Created } from 'data/persistence/activity';
import guid from 'utils/guid';

type AddCallback = (content: ResourceContent, a? : Activity) => void;

export type TitleBarProps = {
  title: string,                  // The title of the resource
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  editMode: boolean,              // Whether or not the user is editing
  onTitleEdit: (title: string) => void;
  onAddItem: AddCallback;
  canUndo: boolean;
  canRedo: boolean;
  onUndo: () => void;
  onRedo: () => void;
  resourceContext: ResourceContext;
};

const ItemCreationDropDown = (
  { editMode, onAddItem, editorMap, resourceContext }
  : {editMode: boolean, onAddItem: AddCallback,
    editorMap: ActivityEditorMap, resourceContext: ResourceContext }) => {

  const handleAdd = (editorDesc: EditorDesc) => {

    let model : ActivityModelSchema;
    invokeCreationFunc(editorDesc.slug, resourceContext)
      .then((createdModel) => {
        model = createdModel;
        return createActivity(resourceContext.projectSlug, editorDesc.slug, model);
      })
      .then((result: Created) => {

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

const UndoRedo = ({ canUndo, canRedo, onUndo, onRedo }
  : {canUndo: boolean, canRedo: boolean, onUndo: () => void, onRedo: () => void}) => {

  return (
    <div className="btn-group btn-group-sm" role="group" aria-label="Undo redo creation">
      <button className={`btn ${canUndo ? '' : 'disabled'}`} type="button" onClick={onUndo}>
        <span><i className="fas fa-undo"></i></span>
      </button>
      <button className={`btn ${canRedo ? '' : 'disabled'}`} type="button" onClick={onRedo}>
      <span><i className="fas fa-redo"></i></span>
      </button>
    </div>
  );
};


export const TitleBar = (props: TitleBarProps) => {

  const { editMode, title, onTitleEdit, onAddItem, canUndo, canRedo } = props;

  const onAddContent = () => onAddItem(createDefaultStructuredContent());

  return (
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1 p-4">
        <TextEditor
          onEdit={onTitleEdit}
          model={title}
          showAffordances={true}
          size="large"
          allowEmptyContents={false}
          editMode={editMode}/>
      </div>

      <UndoRedo {...props}/>
      <ItemCreationDropDown {...props}/>
    </div>
  );
};
