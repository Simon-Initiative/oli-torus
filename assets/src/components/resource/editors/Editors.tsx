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
import { PageEditorContent } from 'data/editor/PageEditorContent';

import './Editors.scss';

export type EditorsProps = {
  className?: ClassName;
  editMode: boolean;
  content: PageEditorContent;
  onEdit: (content: PageEditorContent) => void;
  onRemove: (id: string) => void;
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
  onEditActivity: (id: string, update: EditorUpdate) => void;
  onPostUndoable: (id: string, undoable: Undoable) => void;
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
    resourceContext,
    onAddItem,
    onEditActivity,
    onPostUndoable,
    onRegisterNewObjective,
    onRegisterNewTag,
  } = props;

  const allObjectives = props.objectives.toArray();
  const allTags = props.allTags.toArray();
  const canRemove = content.canDelete();

  const editors = content.model.map((contentItem, index) => {
    const onEdit = (contentItem: ResourceContent) =>
      props.onEdit(content.updateContentItem(contentItem.id, contentItem));
    const onRemove = () => props.onRemove(contentItem.id);

    const editor = createEditor({
      resourceContext: resourceContext,
      contentItem,
      index: [index],
      parents: [],
      activities: activityContexts,
      editMode,
      resourceSlug,
      projectSlug,
      graded,
      objectivesMap,
      allObjectives,
      allTags,
      editorMap,
      canRemove,
      onEdit,
      onEditActivity,
      onPostUndoable,
      onRegisterNewObjective,
      onRegisterNewTag,
      onAddItem,
      onRemove,
    });

    return (
      <div
        key={contentItem.id}
        className={classNames('resource-block-editor-and-controls', contentItem.id)}
      >
        <AddResource
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={[index]}
          parents={[]}
          editMode={editMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          onAddItem={onAddItem}
        />

        <div
          className={classNames('resource-block-editor')}
          role="option"
          aria-describedby="content-list-operation"
          tabIndex={1}
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
        parents={[]}
        onRegisterNewObjective={props.onRegisterNewObjective}
        isLast
        index={[content.model.size]}
        editMode={editMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
      />
    </div>
  );
};
