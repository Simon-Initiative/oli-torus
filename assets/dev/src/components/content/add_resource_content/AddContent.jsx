import { createDefaultStructuredContent } from 'data/content/resource';
import React from 'react';
export const AddContent = ({ onAddItem, index }) => {
    return (<>
      <div className="list-group">
        <a href="#" key={'static_html_content'} className="list-group-item list-group-item-action d-flex flex-column align-items-start" onClick={(_e) => addContent(onAddItem, index)}>
          <div className="type-label">Content</div>
          <div className="type-description">Text, tables, images, video</div>
        </a>
      </div>
    </>);
};
const addContent = (onAddItem, index) => onAddItem(createDefaultStructuredContent(), index);
//# sourceMappingURL=AddContent.jsx.map