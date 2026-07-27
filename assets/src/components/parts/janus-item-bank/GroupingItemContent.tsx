import React from 'react';
import { itemAccessibleText, itemDisplayText, itemImageCaption } from './grouping-util';
import { GroupingItem } from './schema';

interface GroupingItemContentProps {
  item: GroupingItem;
  imageDecorative?: boolean;
}

const GroupingItemContent: React.FC<GroupingItemContentProps> = ({
  item,
  imageDecorative = false,
}) => {
  if (item.type === 'image' && item.imageSrc) {
    const caption = itemImageCaption(item);
    const hasAuthoredAlt = !!item.alt?.trim();
    const imageAlt =
      imageDecorative || (!hasAuthoredAlt && caption) ? '' : itemAccessibleText(item);
    return (
      <div className="grouping-item-content grouping-item-content--image">
        {caption ? <span className="grouping-item-caption">{caption}</span> : null}
        <img className="grouping-item-image" src={item.imageSrc} alt={imageAlt} />
      </div>
    );
  }

  return <span className="grouping-item-label">{itemDisplayText(item)}</span>;
};

export default GroupingItemContent;
