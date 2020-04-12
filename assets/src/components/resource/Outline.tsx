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

// @ts-ignore
const OutlineContent = ({ content, index, onDrop, desc }) => {

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

  return (
    <React.Fragment>
      <DropTarget id={content.id} index={index} onDrop={onDrop}/>
      <div
        draggable={true} key={content.id} className="border-0 p-1"
        onDragStart={handleDragStart}
      >
        <div className="d-flex">
          <DragHandle/>
          <div className="m-2">
            <div className="d-flex justify-content-between">
              <h5 className="mb-1">Content</h5>
              {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
            </div>
            <small>{desc}</small>
          </div>
        </div>
      </div>
    </React.Fragment>
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

  const desc = content.type === 'content'
    ? getContentDescription(content) : editorMap[content.type].friendlyName;

  return (
    <OutlineContent {...props} desc={desc} />
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
          return;

        }
        if (sourceIndex > -1) {
          // Handle a same window drag and drop
          const adjusted = sourceIndex < index ? index - 1 : index;
          const reordered = content.remove(sourceIndex).insert(adjusted, droppedContent);
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
    const onEdit = (updatedComponent : ResourceContent) => {
      const updated = content.set(i, updatedComponent);
      props.onEdit(updated);
    };
    return <OutlineEntry key={c.id} content={c} index={i} editorMap={editorMap} onDrop={onDrop}/>;
  });

  return (
    <div style={ { width: '150px' } }>
      {[...entries, <DropTarget key="last" id="last" index={entries.length} onDrop={onDrop}/>]}
    </div>
  );
};
