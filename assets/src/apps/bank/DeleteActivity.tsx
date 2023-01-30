import React from 'react';

export type DeleteActivityProps = {
  editMode: boolean;
  onDelete: () => void;
};

export const DeleteActivity = (props: DeleteActivityProps) => {
  const { editMode, onDelete } = props;
  return (
    <button
      disabled={!editMode}
      onClick={() => onDelete()}
      type="button"
      className="btn btn-outline-secondary"
      data-toggle="tooltip"
      data-placement="top"
      title="Delete this activity"
      aria-pressed="false"
    >
      <i className="fas fa-trash-alt"></i>
    </button>
  );
};
