import { createDefaultSelection } from 'data/content/resource';
import React from 'react';
export const AddOther = ({ onAddItem, index }) => {
    return (<>
      <div className="list-group">
        <a href="#" key={'static_activity_bank'} className="list-group-item list-group-item-action flex-column align-items-start" onClick={() => onAddItem(createDefaultSelection(), index)}>
          <div className="type-label">Activity Bank Selection</div>
          <div className="type-description">
            Select different activities at random according to defined criteria
          </div>
        </a>
      </div>
    </>);
};
//# sourceMappingURL=AddOther.jsx.map