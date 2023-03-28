import { Tooltip } from 'components/common/Tooltip';
import React from 'react';

export type DeleteBibEntryProps = {
  onDelete: () => void;
};

export const DeleteBibEntry = (props: DeleteBibEntryProps) => {
  const { onDelete } = props;
  return (
    <Tooltip title="Delete this entry">
      <button
        // disabled={!editMode}
        onClick={() => onDelete()}
        type="button"
        className="btn btn-outline-secondary btn-sm"
        aria-pressed="false"
      >
        <i className="fas fa-trash-alt"></i>
      </button>
    </Tooltip>
  );
};
