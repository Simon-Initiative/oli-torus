import React from 'react';
import { itemDisplayText, itemImageCaption } from './matching-util';
import { MatchingItem } from './schema';

interface MatchingItemContentProps {
  item: MatchingItem;
}

const MatchingItemContent: React.FC<MatchingItemContentProps> = ({ item }) => {
  if (item.type === 'image' && item.imageSrc) {
    const caption = itemImageCaption(item);
    return (
      <div className="matching-item-content matching-item-content--image">
        {caption ? <span className="matching-item-caption">{caption}</span> : null}
        <img className="matching-item-image" src={item.imageSrc} alt={item.alt || item.label} />
      </div>
    );
  }

  return <span className="matching-item-label">{itemDisplayText(item)}</span>;
};

export default MatchingItemContent;
