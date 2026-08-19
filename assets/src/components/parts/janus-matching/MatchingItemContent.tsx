import React from 'react';
import { sanitizeRichLabelHtml } from '../../../utils/richOptionLabel';
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
        {caption ? (
          <span
            className="matching-item-caption janus-rich-label"
            dangerouslySetInnerHTML={{ __html: sanitizeRichLabelHtml(caption) }}
          />
        ) : null}
        <img className="matching-item-image" src={item.imageSrc} alt={item.alt || item.label} />
      </div>
    );
  }

  return (
    <span
      className="matching-item-label janus-rich-label"
      dangerouslySetInnerHTML={{ __html: sanitizeRichLabelHtml(itemDisplayText(item)) }}
    />
  );
};

export default MatchingItemContent;
