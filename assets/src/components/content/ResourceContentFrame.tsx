import React from 'react';

import { CloseButton } from '../misc/CloseButton';

export type ResourceContentFrameProps = {
  editMode: boolean,              // Whether or not we can edit
  allowRemoval: boolean,          // Whether or not this item can be removed
  label: string,                  // The content label
  onRemove: () => void,           // Callback for removal
  children: any,
};

// Provides a common frame around any resource content editor
export const ResourceContentFrame = (props: ResourceContentFrameProps) => {

  const { label, onRemove, allowRemoval, children } = props;

  return (
    <div className="card" style={ { width: '100%' } }>
      <div className="card-header">
        <div className="d-flex flex-row align-items-baseline">
          <div className="flex-grow-1">
            {label}
          </div>
          <CloseButton editMode={allowRemoval} onClick={onRemove}/>
        </div>
      </div>
      <div className="card-body">
        {children}
      </div>
    </div>
  );
};
