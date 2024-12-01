import React from 'react';
import * as Immutable from 'immutable';
import { Undoable } from 'components/activities/types';
import { EditorUpdate } from 'components/activity/InlineActivityEditor';
import { FeatureFlags } from 'apps/page-editor/types';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective, ResourceId } from 'data/content/objective';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { PageEditorContent } from 'data/editor/PageEditorContent';
import { ProjectSlug, ResourceSlug } from 'data/types';
import { ClassName, classNames } from 'utils/classNames';
import { AddResource } from './AddResource';
import './Editors.scss';
import { createEditor } from './createEditor';
import { EditorErrorBoundary } from './editor_error_boundary';

export type EditorsProps = {
  className?: ClassName;
  editMode: boolean;
  content: PageEditorContent;
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  graded: boolean;
  activityContexts: Immutable.Map<string, ActivityEditContext>;
  projectSlug: ProjectSlug;
  resourceSlug: ResourceSlug;
  resourceContext: ResourceContext;
  allTags: Immutable.List<Tag>;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  featureFlags: FeatureFlags;
  editorsRef: React.RefObject<HTMLDivElement>;
  onEdit: (content: PageEditorContent) => void;
  onRemove: (id: string) => void;
  onAddItem: (c: ResourceContent, index: number[], a?: ActivityEditContext) => void;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  onEditActivity: (id: string, update: EditorUpdate) => void;
  onPostUndoable: (id: string, undoable: Undoable) => void;
  onDuplicate: (context: ActivityEditContext) => void;
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
    featureFlags,
    editorsRef,
    onAddItem,
    onEditActivity,
    onPostUndoable,
    onRegisterNewObjective,
    onRegisterNewTag,
    onDuplicate,
  } = props;

  const allObjectives = props.objectives.toArray();
  const allTags = props.allTags.toArray();
  const canRemove = editMode;

  const contentBreaksExist = content.model.some((v: ResourceContent) => v.type === 'break');

  const editors = content.model.map((contentItem, index) => {
    const onEdit = (contentItem: ResourceContent) =>
      props.onEdit(content.updateContentItem(contentItem.id, contentItem));

    const onRemove = props.onRemove;

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
      featureFlags,
      contentBreaksExist,
      onEdit,
      onEditActivity,
      onPostUndoable,
      onRegisterNewObjective,
      onRegisterNewTag,
      onAddItem,
      onRemove,
      onDuplicate,
    });

    return (
      <div
        key={contentItem.id}
        className={classNames('resource-block-editor-and-controls', contentItem.id)}
      >
        <AddResource
          index={[index]}
          parents={[]}
          editMode={editMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          featureFlags={featureFlags}
          onAddItem={onAddItem}
          onRegisterNewObjective={props.onRegisterNewObjective}
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
    <div
      ref={editorsRef}
      className={classNames(className, 'editors d-flex flex-column flex-grow-1 shadow-lg')}
    >
      {editors}

      <AddResource
        index={[content.model.size]}
        parents={[]}
        editMode={editMode}
        isLast
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        featureFlags={featureFlags}
        onAddItem={onAddItem}
        onRegisterNewObjective={props.onRegisterNewObjective}
      />
    </div>
  );
};
