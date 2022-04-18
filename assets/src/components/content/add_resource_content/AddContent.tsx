import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultStructuredContent, createGroup } from 'data/content/resource';
import React from 'react';

interface Props {
  onAddItem: AddCallback;
  index: number[];
  level: number;
}
export const AddContent: React.FC<Props> = ({ onAddItem, index, level }) => {
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
        {level === 0 ? (
          <button
            key={'content_group'}
            className="list-group-item list-group-item-action d-flex flex-column align-items-start"
            onClick={(_e) => addGroup(onAddItem, index)}
          >
            <div className="type-label">Group</div>
            <div className="type-description">
              A group for content with the same purpose such as a Checkpoint, Example, Learn by
              doing...{' '}
            </div>
          </button>
        ) : (
          <></>
        )}
      </div>
    </>
  );
};

const addContent = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createDefaultStructuredContent(), index);
  document.body.click();
};

const addGroup = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createGroup(), index);
  document.body.click();
};
