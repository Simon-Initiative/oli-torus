import * as Immutable from 'immutable';
import React from 'react';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { ProjectSlug, ResourceSlug } from 'data/types';
import { Objective, ResourceId } from 'data/content/objective';
import { ClassName, classNames } from 'utils/classNames';
import { AddResource } from './AddResource';
import { createEditor } from './createEditor';
import { EditorUpdate } from 'components/activity/InlineActivityEditor';
import { Undoable } from 'components/activities/types';
import { Tag } from 'data/content/tags';
import { EditorErrorBoundary } from './editor_error_boundary';

import './Editors.scss';
import { PageEditorContent } from 'data/editor/PageEditorContent';

export type EditorsProps = {
  className?: ClassName;
  editMode: boolean; // Whether or not we can edit
  content: PageEditorContent; // Content of the resource
  onEdit: (content: ResourceContent, key: string) => void;
  onRemove: (key: string) => void;
  onAddItem: (c: ResourceContent, index: number[], a?: ActivityEditContext) => void;
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  graded: boolean;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  projectSlug: ProjectSlug;
  resourceSlug: ResourceSlug;
  resourceContext: ResourceContext;
  allTags: Immutable.List<Tag>;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  onActivityEdit: (key: string, update: EditorUpdate) => void;
  onPostUndoable: (key: string, undoable: Undoable) => void;
};

// The list of editors
export const Editors = (props: EditorsProps) => {
  const objectivesMap = props.resourceContext.allObjectives.reduce((m: any, o) => {
    m[o.id] = o.title;
    return m;
  }, {});

  const {
    className,
    editMode,
    graded,
    content,
    activityContexts,
    projectSlug,
    resourceSlug,
    editorMap,
    onAddItem,
    onActivityEdit,
    onPostUndoable,
    onRegisterNewObjective,
  } = props;

  const allObjectives = props.objectives.toArray();
  const allTags = props.allTags.toArray();

  const editors = content.model.map((contentItem, index) => {
    // const contentKey = contentValue.id;
    const onEdit = props.onEdit;
    // const onRemove = () => props.onRemove(contentKey);
    const onEditPurpose = (contentKey: string, purpose: string) => {
      props.onEdit(Object.assign(contentItem, { purpose }), contentKey);
    };

    const editorProps = {
      editMode,
      onEditPurpose,
      content,
      onRemove: props.onRemove,
      canRemove: content.canDelete(),
    };

    const level = 0;

    const editor = createEditor(
      props.resourceContext,
      contentItem,
      index,
      level,
      activityContexts,
      editMode,
      resourceSlug,
      projectSlug,
      graded,
      objectivesMap,
      editorProps,
      allObjectives,
      allTags,
      editorMap,
      onEdit,
      onActivityEdit,
      onPostUndoable,
      onRegisterNewObjective,
      props.onRegisterNewTag,
      onAddItem,
    );

    return (
      <div
        key={'control-container-' + contentItem.id}
        id={`re${contentItem.id}`}
        className={classNames('resource-block-editor-and-controls', contentItem.id)}
      >
        <AddResource
          objectives={props.objectives}
          childrenObjectives={props.childrenObjectives}
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={index}
          level={level}
          editMode={editMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          onAddItem={onAddItem}
        />

        <div
          className={classNames('resource-block-editor')}
          role="option"
          aria-describedby="content-list-operation"
          tabIndex={index + 1}
        >
          <EditorErrorBoundary id={contentItem.id}>{editor}</EditorErrorBoundary>
        </div>
      </div>
    );
  });

  return (
    <div className={classNames(className, 'editors d-flex flex-column flex-grow-1')}>
      {editors}

      <AddResource
        {...props}
        level={0}
        onRegisterNewObjective={props.onRegisterNewObjective}
        isLast
        index={editors.size || 0}
        editMode={editMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
      />
    </div>
  );
};
