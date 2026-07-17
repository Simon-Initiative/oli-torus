import * as React from 'react';

export const FlashcardIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke: _stroke,
  fill: _fill,
  ...props
}) => (
  <img
    src="/images/icons/icon-part-flashcards.svg"
    width={24}
    height={24}
    alt=""
    draggable={false}
    {...props}
  />
);
