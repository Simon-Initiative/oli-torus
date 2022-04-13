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

export type EditorsProps = {
  className?: ClassName;
  editMode: boolean; // Whether or not we can edit
  content: Immutable.OrderedMap<string, ResourceContent>; // Content of the resource
  onEdit: (content: ResourceContent, key: string) => void;
  onRemove: (key: string) => void;
  onAddItem: (c: ResourceContent, index: number, a?: ActivityEditContext) => void;
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

  const editors = content.entrySeq().map(([contentKey, contentValue], index) => {
    const onEdit = (u: ResourceContent) => props.onEdit(u, contentKey);
    const onRemove = () => props.onRemove(contentKey);
    const onEditPurpose = (purpose: string) => {
      props.onEdit(Object.assign(contentValue, { purpose }), contentKey);
    };

    const editorProps = {
      editMode,
      onEditPurpose,
      content,
      onRemove,
    };

    const level = 0;

    const editor = createEditor(
      props.resourceContext,
      contentValue,
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
        key={'control-container-' + contentKey}
        id={`re${contentKey}`}
        className={classNames('resource-block-editor-and-controls', contentKey)}
      >
        <AddResource
          id={contentKey}
          objectives={props.objectives}
          childrenObjectives={props.childrenObjectives}
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={index}
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
          <EditorErrorBoundary id={contentKey}>{editor}</EditorErrorBoundary>
        </div>
      </div>
    );
  });

  return (
    <div className={classNames(className, 'editors d-flex flex-column flex-grow-1')}>
      {editors}

      <AddResource
        {...props}
        onRegisterNewObjective={props.onRegisterNewObjective}
        id="last"
        index={editors.size || 0}
        editMode={editMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
      />
    </div>
  );
};
