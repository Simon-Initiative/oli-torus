import React from 'react';

export type DeleteBibEntryProps = {
  onDelete: () => void;
};

export const DeleteBibEntry = (props: DeleteBibEntryProps) => {
  const { onDelete } = props;
  return (
    <button
      // disabled={!editMode}
      onClick={() => onDelete()}
      type="button"
      className="btn btn-outline-secondary btn-sm"
      data-toggle="tooltip"
      data-placement="top"
      title="Delete this entry"
      aria-pressed="false"
    >
      <i className="fas fa-trash-alt"></i>
    </button>
  );
};
