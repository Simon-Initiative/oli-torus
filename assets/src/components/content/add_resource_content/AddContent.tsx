import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultStructuredContent } from 'data/content/resource';
import React from 'react';

interface Props {
  onAddItem: AddCallback;
  index: number;
}
export const AddContent: React.FC<Props> = ({ onAddItem, index }) => {
  return (
    <>
      <div className="list-group">
        <button
          key={'static_html_content'}
          className="list-group-item list-group-item-action d-flex flex-column align-items-start"
          onClick={(_e) => {
            addContent(onAddItem, index);
            document.body.click();
          }}
        >
          <div className="type-label">Content</div>
          <div className="type-description">Text, tables, images, video</div>
        </button>
      </div>
    </>
  );
};

const addContent = (onAddItem: AddCallback, index: number) =>
  onAddItem(createDefaultStructuredContent(), index);
