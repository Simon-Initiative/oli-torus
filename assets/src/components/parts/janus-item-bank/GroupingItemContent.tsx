import React from 'react';
import { itemDisplayText, itemImageCaption } from './grouping-util';
import { GroupingItem } from './schema';

interface GroupingItemContentProps {
  item: GroupingItem;
}

const GroupingItemContent: React.FC<GroupingItemContentProps> = ({ item }) => {
  if (item.type === 'image' && item.imageSrc) {
    const caption = itemImageCaption(item);
    return (
      <div className="grouping-item-content grouping-item-content--image">
        {caption ? <span className="grouping-item-caption">{caption}</span> : null}
        <img className="grouping-item-image" src={item.imageSrc} alt={item.alt || item.label} />
      </div>
    );
  }

  return <span className="grouping-item-label">{itemDisplayText(item)}</span>;
};

export default GroupingItemContent;
