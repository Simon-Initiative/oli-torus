import * as Immutable from 'immutable';
import React, { useState } from 'react';
import isHotkey from 'is-hotkey';
import {
  ResourceContent,
  Activity,
  ActivityPurposes,
  ContentPurposes,
  ResourceContext,
} from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { ProjectSlug, ResourceSlug } from 'data/types';
import { Objective, ResourceId } from 'data/content/objective';
import { classNames } from 'utils/classNames';
import { AddResourceOrDropTarget } from './AddResourceOrDropTarget';
import { createEditor } from './createEditor';
import { focusHandler } from './dragndrop/handlers/focus';
import { moveHandler } from './dragndrop/handlers/move';
import { dragEndHandler } from './dragndrop/handlers/dragEnd';
import { dropHandler } from './dragndrop/handlers/drop';
import { getDragPayload } from './dragndrop/utils';
import { dragStartHandler } from './dragndrop/handlers/dragStart';

export type EditorsProps = {
  editMode: boolean; // Whether or not we can edit
  content: Immutable.OrderedMap<string, ResourceContent>; // Content of the resource
  onEdit: (content: ResourceContent, key: string) => void;
  onEditContentList: (content: Immutable.OrderedMap<string, ResourceContent>) => void;
  onRemove: (key: string) => void;
  onAddItem: (c: ResourceContent, index: number, a?: Activity) => void;
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  graded: boolean;
  activities: Immutable.Map<string, Activity>;
  projectSlug: ProjectSlug;
  resourceSlug: ResourceSlug;
  resourceContext: ResourceContext;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (text: string) => Promise<Objective>;
};

// The list of editors
export const Editors = (props: EditorsProps) => {
  const objectivesMap = props.resourceContext.allObjectives.reduce((m: any, o) => {
    m[o.id] = o.title;
    return m;
  }, {});

  const {
    editorMap,
    editMode,
    graded,
    content,
    activities,
    projectSlug,
    resourceSlug,
    onEditContentList,
    onAddItem,
  } = props;

  const [assistive, setAssistive] = useState('');
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const isReorderMode = activeDragId !== null;
  const onFocus = focusHandler(setAssistive, content, editorMap, activities);
  const onMove = moveHandler(content, onEditContentList, editorMap, activities, setAssistive);
  const onDragEnd = dragEndHandler(setActiveDragId);
  const onDrop = dropHandler(content, onEditContentList, projectSlug, onDragEnd, editMode);

  const editors = content.entrySeq().map(([contentKey, contentValue], index) => {
    const onEdit = (u: ResourceContent) => props.onEdit(u, contentKey);
    const onRemove = () => props.onRemove(contentKey);
    const onEditPurpose = (purpose: string) => {
      props.onEdit(Object.assign(contentValue, { purpose }), contentKey);
    };

    const purposes =
      contentValue.type === 'activity-reference' ? ActivityPurposes : ContentPurposes;

    const dragPayload = getDragPayload(contentValue, activities, projectSlug);
    const onDragStart = dragStartHandler(dragPayload, contentValue, setActiveDragId);

    // register keydown handlers
    const isShiftArrowDown = isHotkey('shift+down');
    const isShiftArrowUp = isHotkey('shift+up');

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (isShiftArrowDown(e.nativeEvent)) {
        onMove(contentKey, false);
      } else if (isShiftArrowUp(e.nativeEvent)) {
        onMove(contentKey, true);
      }
    };

    const editorProps = {
      purposes,
      onDragStart,
      onDragEnd,
      editMode,
      onEditPurpose,
      content,
      onRemove,
    };

    const editor = createEditor(
      contentValue,
      index,
      activities,
      editorMap,
      editMode,
      resourceSlug,
      projectSlug,
      graded,
      objectivesMap,
      editorProps,
      onEdit,
    );

    return (
      <div
        key={'control-container-' + contentKey}
        id={`re${contentKey}`}
        className={classNames([
          'resource-block-editor-and-controls',
          contentKey,
          contentKey === activeDragId ? 'is-dragging' : '',
        ])}
      >
        <AddResourceOrDropTarget
          id={contentKey}
          objectives={props.objectives}
          childrenObjectives={props.childrenObjectives}
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={index}
          editMode={editMode}
          isReorderMode={isReorderMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          onAddItem={onAddItem}
          onDrop={onDrop}
        />

        <div
          className={classNames(['resource-block-editor', isReorderMode ? 'reorder-mode' : ''])}
          onKeyDown={handleKeyDown}
          onFocus={(_e) => onFocus(contentKey)}
          role="option"
          aria-describedby="content-list-operation"
          tabIndex={index + 1}
        >
          {editor}
        </div>
      </div>
    );
  });

  return (
    <div className="editors d-flex flex-column flex-grow-1">
      {editors}

      <AddResourceOrDropTarget
        {...props}
        id="last"
        index={editors.size || 0}
        editMode={editMode}
        isReorderMode={isReorderMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
        onDrop={onDrop}
      />
    </div>
  );
};
