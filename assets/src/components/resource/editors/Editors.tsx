import * as Immutable from 'immutable';
import React, { useState } from 'react';
import isHotkey from 'is-hotkey';
import {
  ResourceContent, Activity, ActivityPurposes, ContentPurposes, ResourceContext,
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
  editMode: boolean;              // Whether or not we can edit
  content: Immutable.List<ResourceContent>;     // Content of the resource
  onEdit: (content: ResourceContent, index: number) => void;
  onEditContentList: (content: Immutable.List<ResourceContent>) => void;
  onRemove: (index: number) => void;
  onAddItem: (c: ResourceContent, index: number, a?: Activity) => void;
  editorMap: ActivityEditorMap;   // Map of activity types to activity elements
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

  const objectivesMap = props.resourceContext.allObjectives.reduce(
    (m: any, o) => {
      m[o.id] = o.title;
      return m;
    },
    {},
  );

  const {
    editorMap, editMode, graded, content, activities, projectSlug,
    resourceSlug, onEditContentList, onAddItem,
  } = props;

  const [assistive, setAssistive] = useState('');
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const isReorderMode = activeDragId !== null;
  const onFocus = focusHandler(setAssistive, content, editorMap, activities);
  const onMove = moveHandler(content, onEditContentList, editorMap, activities, setAssistive);
  const onDragEnd = dragEndHandler(setActiveDragId);
  const onDrop = dropHandler(content, onEditContentList, projectSlug, onDragEnd, editMode);

  const editors = content.map((c, index) => {

    const onEdit = (u: ResourceContent) => props.onEdit(u, index);
    const onRemove = () => props.onRemove(index);
    const onEditPurpose = (purpose: string) => {
      props.onEdit(Object.assign(c, { purpose }), index);
    };

    const purposes = c.type === 'activity-reference'
      ? ActivityPurposes : ContentPurposes;

    const dragPayload = getDragPayload(c, activities, projectSlug);
    const onDragStart = dragStartHandler(dragPayload, c, setActiveDragId);

    // register keydown handlers
    const isShiftArrowDown = isHotkey('shift+down');
    const isShiftArrowUp = isHotkey('shift+up');

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (isShiftArrowDown(e.nativeEvent)) {
        onMove(index, false);
      } else if (isShiftArrowUp(e.nativeEvent)) {
        onMove(index, true);
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

    const editor = createEditor(c, index, activities, editorMap,
      editMode, resourceSlug,  projectSlug, graded, objectivesMap, editorProps, onEdit);

    return (
      <div key={c.id}
        id={`re${c.id}`}
        className={classNames([
          'resource-block-editor-and-controls',
          c.id, c.id === activeDragId ? 'is-dragging' : '',
        ])}>

        <AddResourceOrDropTarget
          id={c.id}
          objectives={props.objectives}
          childrenObjectives={props.childrenObjectives}
          onRegisterNewObjective={props.onRegisterNewObjective}
          index={index}
          editMode={editMode}
          isReorderMode={isReorderMode}
          editorMap={editorMap}
          resourceContext={props.resourceContext}
          onAddItem={onAddItem}
          onDrop={onDrop} />

        <div className={classNames(['resource-block-editor', isReorderMode ? 'reorder-mode' : ''])}
          onKeyDown={handleKeyDown}
          onFocus={e => onFocus(index)}
          role="option"
          aria-describedby="content-list-operation"
          tabIndex={index + 1}>

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
        index={editors.size}
        editMode={editMode}
        isReorderMode={isReorderMode}
        editorMap={editorMap}
        resourceContext={props.resourceContext}
        onAddItem={onAddItem}
        onDrop={onDrop} />
    </div>
  );
};
