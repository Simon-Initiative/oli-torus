import * as React from 'react';

export interface DragHandleProps {
  hidden?: boolean;
  style?: any;
}

export const DragHandle = (props: DragHandleProps) => {

  const { hidden = false, style = {} } = props;

  return (
    <div className={`drag-handle ${hidden ? 'invisible' : ''}`} style={style}>
      <div className="grip" />
    </div>
  );
};
