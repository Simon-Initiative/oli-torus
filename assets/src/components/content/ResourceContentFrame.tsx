import React from 'react';
import { Purpose } from './Purpose';
import { DeleteButton } from '../misc/DeleteButton';
import { EditLink } from '../misc/EditLink';

import './ResourceContentFrame.scss';

export type ResourceContentFrameProps = {
  editMode: boolean,              // Whether or not we can edit
  allowRemoval: boolean,          // Whether or not this item can be removed
  label: string,                  // The content label
  onRemove: () => void,           // Callback for removal
  onEditPurpose: (purpose: string) => void,
  children: any,
  editingLink?: string,
  purpose: any,
  purposes: any,
};

// Provides a common frame around any resource content editor
export const ResourceContentFrame = (props: ResourceContentFrameProps) => {

  const { label, onRemove, allowRemoval, children, onEditPurpose,
    editingLink, editMode, purpose, purposes } = props;
  const style = { background: 'transparent', padding: 0, margin: 0, marginRight: '8px', border: 0 };
  const link = editingLink !== undefined
    ? (
        <EditLink href={editingLink}/>
      )
    : null;

  return (
    <div className="resource-content-frame card mb-3">
      <div className="card-header">
        <div className="d-flex flex-row align-items-baseline">
          <div className="flex-grow-1">
            {label}
          </div>
          <Purpose purpose={purpose} purposes={purposes}
            editMode={editMode} onEdit={p => onEditPurpose(p)}/>
          {link}
          <DeleteButton editMode={allowRemoval} onClick={onRemove}/>
        </div>
      </div>
      <div className="card-body">
        {children}
      </div>
    </div>
  );
};
