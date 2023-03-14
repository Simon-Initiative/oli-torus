import React from 'react';

export type EditButtonProps = {
  editMode: boolean;
  onChangeEditMode: (state: boolean) => void;
};

export const EditButton = (props: EditButtonProps) => {
  const { editMode, onChangeEditMode } = props;

  return editMode ? (
    <button
      onClick={() => onChangeEditMode(!editMode)}
      type="button"
      className="edit-btn btn btn-sm btn-success mr-1"
      aria-pressed="false"
      data-toggle="tooltip"
      data-placement="top"
      title="Finish editing this activity"
    >
      <i className="fas fa-check"></i> Done
    </button>
  ) : (
    <button
      onClick={() => onChangeEditMode(!editMode)}
      type="button"
      className="edit-btn btn btn-sm btn-warning mr-1"
      aria-pressed="false"
      data-toggle="tooltip"
      data-placement="top"
      title="Enable editing of this activity"
    >
      <i className="fas fa-lock"></i> Edit
    </button>
  );
};
