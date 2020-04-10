import * as Immutable from 'immutable';
import React, { useState } from 'react';
import { ResourceContent } from 'data/content/resource';
import { ActivityEditorMap } from 'data/content/editors';
import { getContentDescription } from 'data/content/utils';

export type ResourceEditorProps = {
  editMode: boolean,              // Whether or not we can edit
  content: Immutable.List<ResourceContent>,     // Content of the resource
  onEdit: (content: Immutable.List<ResourceContent>) => void,
  editorMap: ActivityEditorMap,   // Map of activity types to activity elements
};

// Outline of the content
export const Outline = (props: ResourceEditorProps) => {

  const { editorMap, editMode } = props;
  const content = Immutable.List<ResourceContent>(props.content);

  // Factory for creating top level editors, for things like structured
  // content or referenced activities
  const createEntry = (
    editorMap: ActivityEditorMap,
    content: ResourceContent) : JSX.Element => {

    const handleDragEnter = (e: React.DragEvent<HTMLAnchorElement>) => {
      e.preventDefault();
      e.stopPropagation();
    };
    const handleDragLeave = (e: React.DragEvent<HTMLAnchorElement>) => {
      e.preventDefault();
      e.stopPropagation();
    };
    const handleDrop = (e: React.DragEvent<HTMLAnchorElement>) => {
      e.preventDefault();
      e.stopPropagation();
    };

    if (content.type === 'content') {

      const handleDragStart = (e: React.DragEvent<HTMLAnchorElement>) => {
        const dt = e.dataTransfer;
        const preview = `
          <a href="#" style="margin-top: 0px;" class="list-group-item">
            <div className="d-flex w-100 justify-content-between">
              <h5 className="mb-1">Content</h5>
              <small></small>
            </div>
            <small>${getContentDescription(content)}</small>
          </a>
        `;
        dt.setData('text/html', preview);

        //e.preventDefault();
        //e.stopPropagation();
      };

      return (
        <a draggable={true} href="#" key={content.id} style={ { marginTop: '0px' } } className="list-group-item list-group-item-action"
          onDrop={handleDrop}
          onDragEnter={handleDragEnter}
          onDragLeave={handleDragLeave}
          onDragStart={handleDragStart}
        >
          <div className="d-flex w-100 justify-content-between">
            <h5 className="mb-1">Content</h5>
            {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
          </div>
          <small>{getContentDescription(content)}</small>
        </a>
      );
    }

    const activityEditor = editorMap[content.type];

    return (
      <a href="#" key={content.id} style={ { marginTop: '0px' } } className="list-group-item list-group-item-action"
        onDrop={handleDrop}
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
      >
        <div className="d-flex w-100 justify-content-between">
          <h5 className="mb-1">{activityEditor.friendlyName}</h5>
          {content.purpose !== 'None' ? <small>{content.purpose}</small> : null}
        </div>
        <small></small>
      </a>
    );
  };

  const entries = content.toArray().map((c, i) => {
    const onEdit = (updatedComponent : ResourceContent) => {
      const updated = content.set(i, updatedComponent);
      props.onEdit(updated);
    };
    return createEntry(editorMap, c);
  });

  return (
    <div className="list-group" style={ { width: '150px' } }>
      {entries}
    </div>
  );
};
