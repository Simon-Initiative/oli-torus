import React from 'react';

export type EditBibEntryProps = {
  onEdit: () => void;
};

export const EditBibEntry = (props: EditBibEntryProps) => {
  const { onEdit } = props;
  return (
    <button
      onClick={() => onEdit()}
      type="button"
      className="btn btn-outline-secondary btn-sm"
      data-toggle="tooltip"
      data-placement="top"
      title="Edit this entry"
      aria-pressed="false"
    >
      <i className="las la-edit"></i>
    </button>
  );
};
