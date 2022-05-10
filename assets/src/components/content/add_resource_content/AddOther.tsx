import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultSelection, createBreak } from 'data/content/resource';
import React from 'react';

interface Props {
  onAddItem: AddCallback;
  index: number[];
}

export const AddOther: React.FC<Props> = ({ onAddItem, index }) => {
  return (
    <>
      <div className="list-group">
        <button
          key={'static_activity_bank'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={() => {
            onAddItem(createDefaultSelection(), index);
            document.body.click();
          }}
        >
          <div className="type-label">Activity Bank Selection</div>
          <div className="type-description">
            Select different activities at random according to defined criteria
          </div>
        </button>
        <button
          key={'page_break'}
          className="list-group-item list-group-item-action d-flex flex-column align-items-start"
          onClick={(_e) => addPageBreak(onAddItem, index)}
        >
          <div className="type-label">Content Break</div>
          <div className="type-description">
            Add a content break to split content across multiple pages
          </div>
        </button>
      </div>
    </>
  );
};

const addPageBreak = (onAddItem: AddCallback, index: number[]) => {
  onAddItem(createBreak(), index);
  document.body.click();
};
