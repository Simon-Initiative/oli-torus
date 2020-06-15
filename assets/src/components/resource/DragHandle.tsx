import * as React from 'react';

export interface DragHandleProps {
  hidden?: boolean;
}

export const DragHandle = (props: DragHandleProps) => {

  const { hidden = false } = props;

  return (
    <div className={`drag-handle ${hidden ? 'invisible' : ''}`}>
      <div className="grip" />
    </div>
  );
};
