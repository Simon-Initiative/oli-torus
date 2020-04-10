import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getContentDescription } from 'data/content/utils';
import { toSimpleText } from '../editor/utils';
import { DragHandle } from './DragHandle';

export type ResourceEditorProps = {
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
};

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
  content: ResourceContent,
  editorMap: ActivityEditorMap,
  index: number,
  onDrop: (id: React.DragEvent<HTMLDivElement>, index: number) => void,
};

const OutlineEntry = (props: OutlineEntryProps) => {

  const { content, editorMap } = props;

  const handleDragStart = (e: React.DragEvent<HTMLDivElement>) => {
    const dt = e.dataTransfer;

    // Enables dragging of the underlying JSON of nodes into VSCode for
    // debugging / troubleshooting purposes
    const resource = JSON.stringify([{
      resource: '' + content.id,
      content: JSON.stringify(content, null, 2),
      viewState: null,
      encoding: 'UTF-8',
      mode: null,
      isExternal: false,
    }]);

    dt.setData('CodeEditors', resource);
    dt.setData('application/x-oli-resource-content', JSON.stringify(content));
    dt.setData('text/html', toSimpleText(content));
    dt.setData('text/plain', toSimpleText(content));
    dt.effectAllowed = 'move';

  };

  if (content.type === 'content') {
    return (
      <React.Fragment>
        <DropTarget id={content.id} index={props.index} onDrop={props.onDrop}/>
        <div draggable={true} key={content.id} className="border-0 p-1"
          onDragStart={handleDragStart}
        >
          <div className="d-flex">
            <DragHandle/>
            <div className="m-2">
              <div className="d-flex justify-content-between">
                <h5 className="mb-1">Content</h5>
                {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
              </div>
              <small>{getContentDescription(content)}</small>
            </div>
          </div>
        </div>
      </React.Fragment>
    );
  }

  const activityEditor = editorMap[content.type];

  return (
    <React.Fragment>
      <DropTarget id={content.id} index={props.index} onDrop={props.onDrop}/>
      <div draggable={true} key={content.id} className="m-10"
        onDragStart={handleDragStart}
      >
        <DragHandle/>
        <div className="d-flex w-100 justify-content-between">
          <h5 className="mb-1">{activityEditor.friendlyName}</h5>
          {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
        </div>
        <small></small>
      </div>
    </React.Fragment>
  );
};

// Outline of the content
export const Outline = (props: ResourceEditorProps) => {

  const { editorMap, editMode, onEdit } = props;
  const content = Immutable.List<ResourceContent>(props.content);

  const onDrop = (e: React.DragEvent<HTMLDivElement>, index: number) => {
    if (editMode) {
      const data = e.dataTransfer.getData('application/x-oli-resource-content');

      if (data) {
        const droppedContent = JSON.parse(data);
        const sourceIndex = content.findIndex(c => c.id === droppedContent.id);

        if (sourceIndex === -1) {
          // This is a cross window drop, we insert it
          onEdit(content.insert(index, droppedContent));

        } else if (sourceIndex > -1) {
          // Handle a window to window drop
          const adjusted = sourceIndex < index ? index - 1 : index;
          onEdit(content.remove(sourceIndex).insert(adjusted, droppedContent));
        }
      }
    }
  };

  const entries = content.toArray().map((c, i) => {
    const onEdit = (updatedComponent : ResourceContent) => {
      const updated = content.set(i, updatedComponent);
      props.onEdit(updated);
    };
    return <OutlineEntry content={c} index={i} editorMap={editorMap} onDrop={onDrop}/>;
  });

  return (
    <div style={ { width: '150px' } }>
      {entries}
    </div>
  );
};
