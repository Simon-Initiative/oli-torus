import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { createDefaultSelection } from 'data/content/resource';
import React from 'react';

interface Props {
  onAddItem: AddCallback;
  index: number;
}
export const AddOther: React.FC<Props> = ({ onAddItem, index }) => {
  return (
    <>
      <div className="header">Insert Other</div>
      <div className="list-group">
        <a
          href="#"
          key={'static_activity_bank'}
          className="list-group-item list-group-item-action flex-column align-items-start"
          onClick={() => onAddItem(createDefaultSelection(), index)}
        >
          <div className="type-label">Activity Bank Selection</div>
          <div className="type-description">
            Select different activities at random according to defined criteria
          </div>
        </a>
      </div>
    </>
  );
};
