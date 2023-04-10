import { Tooltip } from 'components/common/Tooltip';
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
    >
      <i className="fas fa-check"></i> Done
    </button>
  ) : (
    <button
      onClick={() => onChangeEditMode(!editMode)}
      type="button"
      className="edit-btn btn btn-sm btn-warning mr-1"
    >
      <i className="fas fa-lock"></i> Edit
    </button>
  );
};
