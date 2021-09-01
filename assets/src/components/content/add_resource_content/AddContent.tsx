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
      <div className="header">Insert Content</div>
      <div className="list-group">
        <a
          href="#"
          key={'static_html_content'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={(_e) => addContent(onAddItem, index)}
        >
          <div className="type-label">HTML</div>
          <div className="type-description">
            Mixed HTML elements including text, tables, images, video
          </div>
        </a>
      </div>
    </>
  );
};

const addContent = (onAddItem: AddCallback, index: number) =>
  onAddItem(createDefaultStructuredContent(), index);
