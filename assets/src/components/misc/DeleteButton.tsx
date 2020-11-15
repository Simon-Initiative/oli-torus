import React from 'react';

export type DeleteButtonProps = {
  onClick: () => void,
  editMode: boolean,
};

export const DeleteButton = (props: DeleteButtonProps) => (
  <button
    style={{
      height: 31,
    }}
    disabled={!props.editMode}
    type="button"
    className="p-0 d-flex align-items-center justify-content-center btn btn-sm btn-delete"
    aria-label="delete"
    onClick={props.onClick}>
    <span className="material-icons" aria-hidden="true">delete</span>
  </button>
);
