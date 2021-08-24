import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultStructuredContent } from 'data/content/resource';
import React from 'react';

interface Props {
  onAddItem: AddCallback;
  index: number;
}
export const AddContent: React.FC<Props> = ({ onAddItem, index }) => {
  return (
    <div className="content">
      <button className="btn insert-content-btn" onClick={(_e) => addContent(onAddItem, index)}>
        <div className="content-icon">
          <span className="material-icons">format_align_left</span>
        </div>
        <div className="content-label">Content</div>
      </button>
    </div>
  );
};

const addContent = (onAddItem: AddCallback, index: number) =>
  onAddItem(createDefaultStructuredContent(), index);
