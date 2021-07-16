import React from 'react';

export type EditingLockProps = {
  editMode: boolean;
  onChangeEditMode: (state: boolean) => void;
};

export const EditingLock = (props: EditingLockProps) => {
  const { editMode, onChangeEditMode } = props;
  const lockState = editMode ? 'unlock' : 'lock';

  return (
    <button
      onClick={() => onChangeEditMode(!editMode)}
      type="button"
      className="btn btn-outline-secondary"
      data-toggle="button"
      aria-pressed="false"
    >
      <i className={`las la-${lockState}`}></i>
    </button>
  );
};
