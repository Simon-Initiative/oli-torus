import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultStructuredContent, createGroup } from 'data/content/resource';
import React from 'react';

interface Props {
  index: number[];
  onAddItem: AddCallback;
}

export const AddContent: React.FC<Props> = ({ onAddItem, index }) => {
  return (
    <>
      <div className="list-group">
        <button
          key={'static_html_content'}
          className="list-group-item list-group-item-action d-flex flex-column align-items-start"
          onClick={(_e) => addContent(onAddItem, index)}
        >
          <div className="type-label">Paragraph</div>
          <div className="type-description">Text, tables, images, video</div>
        </button>
        <button
          key={'content_group'}
          className="list-group-item list-group-item-action d-flex flex-column align-items-start"
          onClick={(_e) => addGroup(onAddItem, index)}
        >
          <div className="type-label">Group</div>
          <div className="type-description">
            A collection of content and activities with a particular layout or similar instructional
            purpose such as a Checkpoint, Example, Learn by doing, etc...{' '}
          </div>
        </button>
      </div>
    </>
  );
};

const addContent = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createDefaultStructuredContent(), index);
  document.body.click();
};

const addGroup = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createGroup(index.length > 1 ? 'none' : 'didigetthis'), index);
  document.body.click();
};
