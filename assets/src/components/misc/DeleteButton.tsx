import React from 'react';

export type DeleteButtonProps = {
  onClick: () => void,
  editMode: boolean,
};

export const DeleteButton = (props: DeleteButtonProps) => (
  <button
    disabled={!props.editMode}
    type="button"
    className="btn btn-sm btn-outline-danger"
    aria-label="delete"
    onClick={props.onClick}>
    <i className="fa fa-trash" aria-hidden="true"></i> Delete
  </button>
);
