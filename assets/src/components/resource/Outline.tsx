import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ProjectSlug } from 'data/types';
import { ResourceContent, Activity, ActivityReference, StructuredContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { toSimpleText } from '../editor/utils';
import { DragHandle } from './DragHandle';
import { getContentDescription } from 'data/content/utils';
import * as Persistence from 'data/persistence/activity';

export type OutlineProps = {
  projectSlug: ProjectSlug,
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
  activities: Immutable.Map<string, Activity>,
};

type DragPayload = StructuredContent | ActivityPayload | UnknownPayload;

interface ActivityPayload {
  type: 'ActivityPayload';
  id: string;
  activity: Activity;
  reference: ActivityReference;
  project: ProjectSlug;
}

interface UnknownPayload {
  type: 'UnknownPayload';
  id: string;
  data: any;
}

// @ts-ignore
const DropTarget = ({ id, index, onDrop }) => {
  const [hovered, setHovered] = useState(false);

  const handleDragEnter = (e: React.DragEvent<HTMLDivElement>) => setHovered(true);
  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => setHovered(false);
  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setHovered(false);
    onDrop(e, index);
  };
  const handleOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.stopPropagation();
    e.preventDefault();
  };

  const backgroundColor = hovered ? 'orange' : undefined;

  return (
    <div key={id + '-drop'} className="border-0 p-1"
      style={ { backgroundColor } }
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      onDragOver={handleOver}
    >
    </div>
  );
};


// Outline of the content
type OutlineEntryProps = {
  description: string | JSX.Element,
  dragPayload: DragPayload,
  content: ResourceContent,
  editorMap: ActivityEditorMap,
  activities: Immutable.Map<string, Activity>,
  index: number,
  onDrop: (id: React.DragEvent<HTMLDivElement>, index: number) => void,
  onFocus: (index: number) => void,
  onMove: (index: number, up: boolean) => void,
};

const OutlineEntry = (props: OutlineEntryProps) => {

  const { content, dragPayload, index, onDrop, description, onFocus, onMove } = props;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.shiftKey && e.key === 'ArrowDown') {
      onMove(index, false);
    } else if (e.shiftKey && e.key === 'ArrowUp') {
      onMove(index, true);
    }
  };

  const handleDragStart = (e: React.DragEvent<HTMLDivElement>) => {
    const dt = e.dataTransfer;

    // Enables dragging of the underlying JSON of nodes into VSCode for
    // debugging / troubleshooting purposes
    const resource = JSON.stringify([{
      resource: '' + content.id,
      content: JSON.stringify(dragPayload, null, 2),
      viewState: null,
      encoding: 'UTF-8',
      mode: null,
      isExternal: false,
    }]);

    dt.setData('CodeEditors', resource);
    dt.setData('application/x-oli-resource-content', JSON.stringify(dragPayload));
    dt.setData('text/html', toSimpleText(content));
    dt.setData('text/plain', toSimpleText(content));
    dt.effectAllowed = 'move';

  };

  return (
    <div
      onKeyDown={handleKeyDown}
      onFocus={e => onFocus(index)}
      role="option"
      aria-describedby="outline-list-operation"
      tabIndex={index}
      style={ { paddingLeft: '4px', paddingRight: '4px' } }>

      <DropTarget id={content.id} index={index} onDrop={onDrop}/>

      <div
        draggable={true} key={content.id}
        onDragStart={handleDragStart}
      >
        <div className="d-flex">
          <DragHandle/>
          <div className="m-2 text-truncate">
            <div className="d-flex justify-content-between">
              <div className="mb-1">{content.type === 'content' ? 'Content' : 'Activity'}</div>
              {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
            </div>
            <small>{description}</small>
          </div>
        </div>
      </div>
    </div>
  );
};


// Outline of the content
export const Outline = (props: OutlineProps) => {

  const { editorMap, editMode, onEdit, activities, projectSlug } = props;
  const content = Immutable.List<ResourceContent>(props.content);
  const [assisstive, setAssisstive] = useState('');

  const onFocus = (index: number) => {
    const item = content.get(index) as ResourceContent;
    const desc = item.type === 'content'
      ? getContentDescription(item) : editorMap[item.type].friendlyName;

    setAssisstive(
      `Listbox. ${index + 1} of ${content.size}. ${desc}.`);
  };

  const onMove = (index: number, up: boolean) => {

    if (index === 0 && up) return;

    const item = content.get(index) as ResourceContent;
    const inserted = content
      .remove(index)
      .insert(index + (up ? -1 : 1), item as any);

    onEdit(inserted);

    const newIndex = inserted.findIndex(c => c.id === item.id);
    const desc = item.type === 'content'
      ? 'Content' : editorMap[item.type].friendlyName;

    setAssisstive(
      `Listbox. ${newIndex + 1} of ${content.size}. ${desc}.`);
  };

  const onDrop = (e: React.DragEvent<HTMLDivElement>, index: number) => {
    if (editMode) {
      const data = e.dataTransfer.getData('application/x-oli-resource-content');

      if (data) {
        const droppedContent = JSON.parse(data) as DragPayload;

        const sourceIndex = content.findIndex(c => c.id === droppedContent.id);

        if (sourceIndex === -1) {

          // This is a cross window drop, we insert it but have to have to
          // ensure that for activities that we create a new activity for
          // tied to this project
          if (droppedContent.type === 'ActivityPayload') {

            if (droppedContent.project !== projectSlug) {

              Persistence.create(
                droppedContent.project,
                droppedContent.activity.typeSlug,
                droppedContent.activity.model)
              .then((result: Persistence.Created) => {
                onEdit(content.insert(index, droppedContent.reference));
              });

            } else {
              onEdit(content.insert(index, droppedContent.reference));
            }


          } else if (droppedContent.type === 'content') {
            onEdit(content.insert(index, droppedContent));
          } else {
            onEdit(content.insert(index, droppedContent.data));
          }

          return;

        }
        if (sourceIndex > -1) {
          // Handle a same window drag and drop
          const adjusted = sourceIndex < index ? index - 1 : index;

          let toInsert;
          if (droppedContent.type === 'ActivityPayload') {
            toInsert = droppedContent.reference;
          } else if (droppedContent.type === 'content') {
            toInsert = droppedContent;
          } else {
            toInsert = droppedContent.data;
          }

          const reordered = content.remove(sourceIndex).insert(adjusted, toInsert);
          onEdit(reordered);
          return;
        }
      }

      // Handle a drag and drop from VSCode
      const text = e.dataTransfer.getData('codeeditors');
      if (text) {
        try {
          const json = JSON.parse(text);
          const parsedContent = JSON.parse(json[0].content);

          // Remove it if we find the same identified content item
          const inserted = content
            .filter(c => parsedContent.id !== c.id)
            // Then insert it
            .insert(index, parsedContent);

          onEdit(inserted);
        } catch (err) {

        }
      }

    }
  };

  const entries = content.toArray().map((c, i) => {

    let description;
    let dragPayload : DragPayload;
    if (c.type === 'content') {
      description = getContentDescription(c);
      dragPayload = c;
    } else if (activities.has(c.activitySlug)) {
      const activity = activities.get(c.activitySlug);
      description = editorMap[(activity as any).typeSlug].friendlyName;
      dragPayload = {
        type: 'ActivityPayload',
        id: c.id,
        reference: c,
        activity: activity as Activity,
        project: projectSlug,
      } as ActivityPayload;
    } else {
      description = 'Unknown';
      dragPayload = { type: 'UnknownPayload', data: c, id: c.id };
    }

    return (
      <OutlineEntry
        key={c.id}
        description={description}
        dragPayload={dragPayload}
        content={c}
        activities={activities}
        index={i}
        editorMap={editorMap}
        onMove={onMove}
        onDrop={onDrop}
        onFocus={onFocus}/>
    );
  });

  return (
    <div style={ { width: '150px' } } role="listbox">
      <span aria-live="assertive" className="assistive-text">
        {assisstive}
      </span>
      <span id="outline-list-operation" className="assistive-text">
        Press shift key to reorder items
      </span>
      {[...entries, <DropTarget key="last" id="last" index={entries.length}
        onDrop={onDrop}/>]}
    </div>
  );
};
